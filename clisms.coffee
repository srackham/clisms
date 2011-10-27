#!/usr/bin/env coffee

MAN_PAGE = -> """

NAME
  #{PROG} - Send SMS message

SYNOPSIS
  #{PROG} PHONE MESSAGE
  #{PROG} -s MSGID
  #{PROG} -b | -l

DESCRIPTION
  A simple command-line script to send SMS messages using
  Clickatell's HTTP API (see http://clickatell.com).
  Records messages log in #{LOG_FILE}.
  Reads configuration parameters from #{CONF_FILE}

OPTIONS
  -s MSGID
    Query message delivery status.

  -b
    Query account balance.

  -l
    List message log file using #{PAGER}.

  -p
    List phone book.

AUTHOR
  Written by Stuart Rackham, <srackham@gmail.com>

COPYING
  Copyright (C) 2011 Stuart Rackham. Free use of this software is
  granted under the terms of the MIT License.
"""
VERSION = '0.3.0'

{spawn} = require 'child_process'
path = require 'path'
fs = require 'fs'
http = require 'http'
querystring = require 'querystring'

# Clickatell account configuration parameters.
# The configuration file is single JSON formatted object with the
# same attributes and attribute types as the default CONF variable below.
# Alternatively you could dispense with the configuration file and edit the
# values in the CONF variable below.
CONF =
  USERNAME: ''
  PASSWORD: ''
  API_ID: ''
  SENDER_ID: ''  # Your registered mobile phone number.
  PHONE_BOOK: {}

ARGV = process.argv[1..]  # Drop 'coffee' interpreter from arguments.
ARGC = ARGV.length
PROG = path.basename ARGV[0]
HOME = process.env.HOME ? process.env.HOMEPATH
LOG_FILE = path.join HOME, 'sms.log'
PAGER = process.env.PAGER ? 'less'
CONF_FILE = path.join HOME, '.clisms.json'
if path.existsSync CONF_FILE
  CONF = JSON.parse fs.readFileSync(CONF_FILE)

# URL query string parameters.
QUERY =
  user:   CONF.USERNAME
  password: CONF.PASSWORD
  api_id:   CONF.API_ID
  concat:   3

# Clickatell status messages.
MSG_STATUS =
  '001': 'message unknown'
  '002': 'message queued'
  '003': 'delivered to gateway'
  '004': 'received by recipient'
  '005': 'error with message'
  '007': 'error delivering message'
  '008': 'OK'
  '009': 'routing error'
  '012': 'out of credit'

# Utility functions.
String::startswith = (s) -> s == this[0...s.length]
String::endswith = (s) -> s == this[-s.length..]

# Execute Clickatell HTTP command.
# The `process_response` function is called with the HTTP reponse data string.
http_cmd = (cmd, process_response) ->
  query = querystring.stringify QUERY
  url =
    host: 'api.clickatell.com'
    port: 80
    path: "/http/#{cmd}?#{query}"
  http.get url, (response) ->
    data = ''
    response.on 'data', (chunk) -> data += chunk
    response.on 'end', -> process_response(data)

# Print Clickatell account balance.
print_account_balance = ->
  http_cmd 'getbalance', (result) -> console.info result

# Print the status of a previously sent message.
print_message_status = (msgid) ->
  QUERY['apimsgid'] = msgid
  http_cmd 'getmsgcharge', (result) ->
    console.info result + ' (' + (MSG_STATUS[result[-3..]] ? '') + ')'

# Strip number punctuation and check the number is not obviously illegal.
sanitize_phone_number = (number) ->
  result = number.replace /[+ ()-]/g, ''
  if not result.match /^\d+$/
    console.info "illegal phone number: #{number}"
    process.exit 1
  return result

# Send text message. The recipient phone number can be a phone number
# or the name of a phone book entry.
send_message = (text, to) ->
  if CONF.PHONE_BOOK[to]?
    name = to
    to = CONF.PHONE_BOOK[to]
  else
    name = null
  to = sanitize_phone_number to
  sender_id = sanitize_phone_number CONF.SENDER_ID
  if sender_id.startswith('64') and to.startswith('6427')
    # Use local number format if sending to Telecom NZ mobile from a NZ
    # number (to work around Telecom NZ blocking NZ originating messages
    # from Clickatell).
    sender_id = '0' + sender_id[2..]
  QUERY.from = sender_id
  QUERY.to = to
  QUERY.text = text
  http_cmd 'sendmsg', (result) ->
    now = new Date
    if name
      to += ": #{name}"
    fd = fs.createWriteStream LOG_FILE, {flags: 'a'}
    fd.write """
      to:   #{to}
      from: #{sender_id}
      date: #{now.toLocaleDateString() + ', ' + now.toLocaleTimeString()}
      result: #{result}
      text: #{text}\n\n
      """
    fd.end()
    console.info result


# Main.
if ARGC == 3
  if ARGV[1] == '-s'
    print_message_status ARGV[2]
  else
    send_message ARGV[2], ARGV[1]
else if ARGC == 2
  switch ARGV[1]
    when '-b'
      print_account_balance()
    when '-l' # View log file in pager.
      pager = spawn PAGER, [LOG_FILE],
        customFds: [process.stdin, process.stdout, process.stderr]
    when '-p'
      for name, number of CONF.PHONE_BOOK
        console.info "#{name}: #{number}"
else
  console.info MAN_PAGE()

#!/usr/bin/env node
(function() {
  var ARGC, ARGV, CONF, CONF_FILE, HOME, LOG_FILE, MAN_PAGE, MSG_STATUS, PAGER, PROG, QUERY, VERSION, fs, http, http_cmd, name, number, path, print_account_balance, print_message_status, querystring, sanitize_phone_number, send_message, shell, spawn, _ref, _ref2, _ref3;

  MAN_PAGE = function() {
    return "\nNAME\n  " + PROG + " - Send SMS message\n\nSYNOPSIS\n  " + PROG + " PHONE MESSAGE\n  " + PROG + " -s MSGID\n  " + PROG + " -b | -l\n\nDESCRIPTION\n  A simple command-line script to send SMS messages using\n  Clickatell's HTTP API (see http://clickatell.com).\n  Records messages log in " + LOG_FILE + ".\n  Reads configuration parameters from " + CONF_FILE + "\n\nOPTIONS\n  -s MSGID\n    Query message delivery status.\n\n  -b\n    Query account balance.\n\n  -l\n    List message log file using " + PAGER + ".\n\n  -p\n    List phone book.\n\nAUTHOR\n  Written by Stuart Rackham, <srackham@gmail.com>\n\nCOPYING\n  Copyright (C) 2011 Stuart Rackham. Free use of this software is\n  granted under the terms of the MIT License.";
  };

  VERSION = '0.3.5';

  spawn = require('child_process').spawn;

  path = require('path');

  fs = require('fs');

  http = require('http');

  querystring = require('querystring');

  CONF = {
    USERNAME: '',
    PASSWORD: '',
    API_ID: '',
    SENDER_ID: '',
    PHONE_BOOK: {}
  };

  ARGV = process.argv.slice(1);

  ARGC = ARGV.length;

  PROG = path.basename(ARGV[0]);

  HOME = (_ref = process.env.HOME) != null ? _ref : process.env.HOMEPATH;

  LOG_FILE = path.join(HOME, 'clisms.log');

  PAGER = (_ref2 = process.env.PAGER) != null ? _ref2 : 'less';

  CONF_FILE = path.join(HOME, '.clisms.json');

  if (((fs != null ? fs.existsSync : void 0) || (path != null ? path.existsSync : void 0))(CONF_FILE)) {
    CONF = JSON.parse(fs.readFileSync(CONF_FILE));
  }

  QUERY = {
    user: CONF.USERNAME,
    password: CONF.PASSWORD,
    api_id: CONF.API_ID,
    concat: 3,
    req_feat: 32
  };

  MSG_STATUS = {
    '001': 'message unknown',
    '002': 'message queued',
    '003': 'delivered to gateway',
    '004': 'received by recipient',
    '005': 'error with message',
    '007': 'error delivering message',
    '008': 'OK',
    '009': 'routing error',
    '012': 'out of credit'
  };

  String.prototype.startsWith = function(s) {
    return s === this.slice(0, s.length);
  };

  String.prototype.endsWith = function(s) {
    return s === this.slice(-s.length);
  };

  shell = function(cmd, opts, callback) {
    var child;
    process.stdin.pause();
    child = spawn(cmd, opts, {
      customFds: [0, 1, 2]
    });
    return child.on('exit', function(code) {
      process.stdin.resume();
      return callback(code);
    });
  };

  http_cmd = function(cmd, process_response) {
    var query, url;
    query = querystring.stringify(QUERY);
    url = {
      host: 'api.clickatell.com',
      port: 80,
      path: "/http/" + cmd + "?" + query
    };
    return http.get(url, function(response) {
      var data;
      data = '';
      response.on('data', function(chunk) {
        return data += chunk;
      });
      return response.on('end', function() {
        return process_response(data);
      });
    });
  };

  print_account_balance = function() {
    return http_cmd('getbalance', function(result) {
      return console.info(result);
    });
  };

  print_message_status = function(msgid) {
    QUERY['apimsgid'] = msgid;
    return http_cmd('getmsgcharge', function(result) {
      var _ref3;
      return console.info(result + ' (' + ((_ref3 = MSG_STATUS[result.slice(-3)]) != null ? _ref3 : '') + ')');
    });
  };

  sanitize_phone_number = function(number) {
    var result;
    result = number.replace(/[+ ()-]/g, '');
    if (!result.match(/^\d+$/)) {
      console.info("illegal phone number: " + number);
      process.exit(1);
    }
    return result;
  };

  send_message = function(text, to) {
    var name, sender_id;
    if (CONF.PHONE_BOOK[to] != null) {
      name = to;
      to = CONF.PHONE_BOOK[to];
    } else {
      name = null;
    }
    to = sanitize_phone_number(to);
    sender_id = sanitize_phone_number(CONF.SENDER_ID);
    QUERY.from = sender_id;
    QUERY.to = to;
    QUERY.text = text;
    return http_cmd('sendmsg', function(result) {
      var fd, now;
      now = new Date;
      if (name) to += ": " + name;
      fd = fs.createWriteStream(LOG_FILE, {
        flags: 'a'
      });
      fd.write("to:   " + to + "\nfrom: " + sender_id + "\ndate: " + (now.toLocaleDateString() + ', ' + now.toLocaleTimeString()) + "\nresult: " + result + "\ntext: " + text + "\n\n");
      fd.end();
      return console.info(result);
    });
  };

  if (ARGC === 3) {
    if (ARGV[1] === '-s') {
      print_message_status(ARGV[2]);
    } else {
      send_message(ARGV[2], ARGV[1]);
    }
  } else if (ARGC === 2) {
    switch (ARGV[1]) {
      case '-b':
        print_account_balance();
        break;
      case '-l':
        shell(PAGER, [LOG_FILE], function() {
          return process.exit();
        });
        break;
      case '-p':
        _ref3 = CONF.PHONE_BOOK;
        for (name in _ref3) {
          number = _ref3[name];
          console.info("" + name + ": " + number);
        }
    }
  } else {
    console.info(MAN_PAGE());
  }

}).call(this);

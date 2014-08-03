#!/usr/bin/env node
/*
Verbatim port from CoffeeScript of:
https://github.com/srackham/clisms/blob/master/clisms.coffee
which in turn was a verbatim port of:
https://srackham.wordpress.com/2010/03/23/command-line-sms-script/
*/
/// <reference path='node.d.ts'/>
var child_process = require('child_process');
var path = require('path');
var fs = require('fs');
var http = require('http');
var querystring = require('querystring');

var Clisms;
(function (Clisms) {
    function man_page() {
        return [
            '',
            'NAME',
            '  ' + PROG + ' - Send SMS message',
            '',
            'SYNOPSIS',
            '  ' + PROG + ' PHONE MESSAGE',
            '  ' + PROG + ' -s MSGID',
            '  ' + PROG + ' -b | -l',
            '',
            'DESCRIPTION',
            '  A simple command-line script to send SMS messages using',
            '  Clickatell\'s HTTP API (see http://clickatell.com).',
            '  Records messages log in ' + LOG_FILE + '.',
            '  Reads configuration parameters from ' + CONF_FILE + '',
            '  Version ' + VERSION + ' compiled from TypeScript source.',
            '',
            'OPTIONS',
            '  -s MSGID',
            '    Query message delivery status.',
            '',
            '  -b',
            '    Query account balance.',
            '',
            '  -l',
            '    List message log file using ' + PAGER + '.',
            '',
            '  -p',
            '    List phone book.',
            '',
            'AUTHOR',
            '  Written by Stuart Rackham, <srackham@gmail.com>',
            '',
            'COPYING',
            '  Copyright (C) 2011 Stuart Rackham. Free use of this software is',
            '  granted under the terms of the MIT License.'
        ].join('\n');
    }

    var VERSION = '0.4.1';

    var ARGV = process.argv.slice(1);
    var ARGC = ARGV.length;
    var PROG = path.basename(ARGV[0]);
    var HOME = process.env.HOME || process.env.HOMEPATH;
    var LOG_FILE = path.join(HOME, 'clisms.log');
    var PAGER = process.env.PAGER || 'less';
    var CONF_FILE = path.join(HOME, '.clisms.json');

    // Clickatell account configuration parameters.
    // The configuration file is single JSON formatted object with the
    // same attributes and attribute types as the default CONF variable below.
    // Alternatively you could dispense with the configuration file and edit the
    // values in the CONF variable below.
    var CONF = {
        USERNAME: '',
        PASSWORD: '',
        API_ID: '',
        SENDER_ID: '',
        PHONE_BOOK: {}
    };

    // path.existsSync is deprecated in node 0.7+.
    if ((fs['existsSync'] || path['existsSync'])(CONF_FILE)) {
        CONF = JSON.parse(fs.readFileSync(CONF_FILE, 'utf8'));
    }

    // Clickatell API URL query parameters.
    var QUERY = {
        user: CONF.USERNAME,
        password: CONF.PASSWORD,
        api_id: CONF.API_ID,
        concat: 3,
        req_feat: 32
    };

    // Clickatell status messages.
    var MSG_STATUS = {
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

    /* Utility functions */
    // Execute shell command. 'cmd' is executable path; 'opts' is arguments array;
    // 'callback' is executed and passed the process exit code when the command
    // exits.
    function shell(cmd, opts, callback) {
        var child;
        process.stdin.pause();
        child = child_process.spawn(cmd, opts, { customFds: [0, 1, 2] });
        child.on('exit', function (code) {
            process.stdin.resume();
            callback(code);
        });
    }
    ;

    // Execute Clickatell HTTP command.
    // The process_response function is called with the HTTP reponse data string.
    function http_cmd(cmd, process_response) {
        var query, url;
        query = querystring.stringify(QUERY);
        url = {
            host: 'api.clickatell.com',
            port: 80,
            path: '/http/' + cmd + '?' + query
        };
        http.get(url, function (response) {
            var data;
            data = '';
            response.on('data', function (chunk) {
                return data += chunk;
            });
            response.on('end', function () {
                return process_response(data);
            });
        });
    }
    ;

    // Strip number punctuation and check the number is not obviously illegal.
    function sanitize_phone_number(num) {
        var result;
        result = num.replace(/[+ ()-]/g, '');
        if (!result.match(/^\d+$/)) {
            console.info('illegal phone number: ' + num);
            process.exit(1);
        }
        return result;
    }
    ;

    /* Command options functions */
    // Print Clickatell account balance.
    function print_account_balance() {
        http_cmd('getbalance', function (result) {
            return console.info(result);
        });
    }
    ;

    // Print the status of a previously sent message.
    function print_message_status(msgid) {
        QUERY['apimsgid'] = msgid;
        http_cmd('getmsgcharge', function (result) {
            return console.info(result + ' (' + (MSG_STATUS[result.slice(-3)] || '') + ')');
        });
    }
    ;

    //  Send text message. The recipient phone number can be a phone number
    //  or the name of a phone book entry.
    function send_message(text, to) {
        var name, sender_id;
        if (CONF.PHONE_BOOK[to]) {
            name = to;
            to = CONF.PHONE_BOOK[to];
        } else {
            name = null;
        }
        to = sanitize_phone_number(to);
        sender_id = sanitize_phone_number(CONF.SENDER_ID);
        QUERY['from'] = sender_id;
        QUERY['to'] = to;
        QUERY['text'] = text;
        http_cmd('sendmsg', function (result) {
            var fd, now;
            now = new Date;
            if (name)
                to += ': ' + name;
            fd = fs.createWriteStream(LOG_FILE, { flags: 'a' });
            fd.write('to:   ' + to + '\n' + 'from: ' + sender_id + '\n' + 'date: ' + (now.toLocaleDateString() + ', ' + now.toLocaleTimeString()) + '\n' + 'result: ' + result + '\ntext: ' + text + '\n\n');
            fd.end();
            console.info(result);
        });
    }
    ;

    /* Main */
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
                shell(PAGER, [LOG_FILE], function () {
                    return process.exit();
                });
                break;
            case '-p':
                for (name in CONF.PHONE_BOOK) {
                    console.info(name + ': ' + CONF.PHONE_BOOK[name]);
                }
        }
    } else {
        console.info(man_page() + '\n');
    }
})(Clisms || (Clisms = {}));

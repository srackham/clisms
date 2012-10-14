import 'dart:io';
import 'dart:json';
import 'dart:uri';

MAN_PAGE() => '''

NAME
  ${PROG} - Send SMS message

SYNOPSIS
  ${PROG} PHONE MESSAGE
  ${PROG} -s MSGID
  ${PROG} -b | -l | -p

DESCRIPTION
  A simple command-line script to send SMS messages using
  Clickatell's HTTP API (see http://clickatell.com).
  Records messages log in ${LOG_FILE}.
  Reads configuration parameters from ${CONF_FILE}
  Version ${VERSION} executed from Dart source.

OPTIONS
  -s MSGID
    Query message delivery status.

  -b
    Query account balance.

  -l
    List message log file using ${PAGER}.

  -p
    List phone book.

AUTHOR
  Written by Stuart Rackham, <srackham@gmail.com>

COPYING
  Copyright (C) 2012 Stuart Rackham. Free use of this software is
  granted under the terms of the MIT License.
''';

const VERSION = '0.4.1';

// Clickatell account configuration parameters.
// The configuration file is single JSON formatted object with the
// same attributes and attribute types as the default CONF variable below.
// Alternatively you could dispense with the configuration file and edit the
// values in the CONF variable below.
final CONF = {
  'USERNAME': '',
  'PASSWORD': '',
  'API_ID': '',
  'SENDER_ID': '',  // Your registered mobile phone number.
  'PHONE_BOOK': {}
};


int ARGC;
List<String> ARGV;
String PROG;
String HOME;
String PAGER;
Path LOG_FILE;
Path CONF_FILE;

void main() {
  Options OPTS = new Options();
  ARGV = OPTS.arguments;
  ARGC = ARGV.length;
  PROG = new Path(OPTS.script).filename;
  HOME = Platform.environment['HOME'];
  HOME = HOME == null ? Platform.environment['HOMEPATH'] : HOME;
  PAGER = Platform.environment['PAGER'];
  if (PAGER == null) PAGER = 'less';
  LOG_FILE = new Path(HOME).join(new Path('clisms.log'));
  CONF_FILE = new Path(HOME).join(new Path('.clisms.json'));
  var f = new File.fromPath(CONF_FILE);
  if (f.existsSync()) {
    CONF = JSON.parse(f.readAsTextSync());
  }

  if (ARGC == 2) {
    if (ARGV[0] == '-s')
      printMessageStatus(ARGV[1]);
    else
      sendMessage(ARGV[0], ARGV[1]);
  }
  else if (ARGC == 1) {
    switch (ARGV[0]) {
      case '-b':
        printAccountBalance();
        break;
      case '-l':  // View log file in pager.
        shell(PAGER, [LOG_FILE.toString()], (exitCode) => exit(exitCode));
        break;
      case '-p':
        CONF['PHONE_BOOK'].forEach(
            (name, number) => print('${name}: ${number}')
        );
        break;
      default:
        die('Illegal option: ${ARGV[0]}');
    }
  }
  else
    print(MAN_PAGE());
}

// URL query string parameters.
final QUERY = {
  'user':   CONF['USERNAME'],
  'password': CONF['PASSWORD'],
  'api_id':   CONF['API_ID'],
  'concat':   3,
  'req_feat': 32  // Gateway must support numeric sender ID.
};

// Clickatell status messages.
final MSG_STATUS = {
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

// Execute shell command. 'cmd' is executable path; 'args' is arguments array;
// 'onExit' is executed and passed the process exit code when the command
// exits.
void shell(String cmd, List<String> args, void onExit(int exitCode)) {
  var p = Process.start(cmd, args);
  p.stdout.pipe(stdout);
  stdin.pipe(p.stdin);
  p.onExit = (exitCode) {
    p.close();
    onExit(exitCode);
  };
}

/**
Execute Clickatell HTTP command.
The `processResponse` function is called with the HTTP response data string.
*/
void httpCmd(String cmd, void processResponse(String data)) {
  // Encode URI query parameters.
  var params = [];
  QUERY.forEach((k, v) {
    params.add('${encodeUriComponent(k.toString())}='
        '${encodeUriComponent(v.toString())}');
    });
  var query = Strings.join(params, '&');
  var httpClient = new HttpClient();
  HttpClientConnection conn = httpClient.get(
      'api.clickatell.com', 80, '/http/${cmd}?${query}');
  conn.onResponse = (HttpClientResponse response) {
    StringInputStream stream = new StringInputStream(response.inputStream);
    StringBuffer data = new StringBuffer();
    stream.onData = () => data.add(stream.read());
    stream.onClosed = () {
      processResponse(data.toString());
    };
  };
}

/// Print the status of a previously sent message.
void printMessageStatus(String messageId) {
  QUERY['apimsgid'] = messageId;
  httpCmd('getmsgcharge', (data) {
    //TODO String.slice(startIndex, [endIndex])) method and Map.get(k, ifAbsent)
    //     s = MSG_STATUS.get(data.slice(-3), '');
    //     ifAbsent is var not function (belts and braces overkill).
    var i = data.length - 3;
    if (i < 0) i = 0;
    var s = MSG_STATUS[data.substring(i)];
    if (s == null) s = '';
    print('$data  ($s)');
  });
}

// Strip number punctuation and check the number is not obviously illegal.
String sanitizePhoneNumber(String number) {
  var result = number.replaceAll(new RegExp(r'[+ ()-]'), '');
  if (! new RegExp(r'^\d+$').hasMatch(result)) {
    die('illegal phone number: ${number}');
  }
  return result;
}

// Send text message. The recipient phone number can be a phone number
// or the name of a phone book entry.
void sendMessage(String to, String text) {
  var name;
  if (CONF['PHONE_BOOK'][to] != null) {
    name = to;
    to = CONF['PHONE_BOOK'][to];
  }
  to = sanitizePhoneNumber(to);
  var sender_id = sanitizePhoneNumber(CONF['SENDER_ID']);
  QUERY['from'] = sender_id;
  QUERY['to'] = to;
  QUERY['text'] = text;
  httpCmd('sendmsg', (result) {
    var now = new Date.now();
    if (name != null) to = '$to: $name';
    OutputStream out = new File.fromPath(LOG_FILE)
        .openOutputStream(FileMode.APPEND);
    out.writeString('''
to:   ${to}
from: ${sender_id}
date: ${now.toString()}
result: ${result}
text: ${text}\n
''');
    out.close();
    print(result);
  });
}

void printAccountBalance() {
  httpCmd('getbalance', (data) => print(data));
}

void die(String message, [int status=1]) {
  stderr.writeString(message);
  exit(status);
}

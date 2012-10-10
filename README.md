## clisms

A command-line script to send SMS messages using
http://clickatell.com[Clickatell's] SMS gateway.

Runs under http://nodejs.org/[NodeJS] (NodeJS must be installed). The
easiest way to install is using http://npmjs.org/[npm]:

    npm install clisms

Run using the `clisms` command.

**NOTE:** Before you can use `clisms` you need to have a Clickatell HTTP
SMS account and you must create a `.clisms.json` configuration file in
your home directory containing your Clickatell login parameters (see
the example below).

#### Features

- Records sent messages in a log and has command option to view log
  file.
- Has command options to query the Clickatell account balance and the
  status of previously sent messages.
- Configuration options to map names to phone numbers.


#### Example usage

    $ clisms 64912345667 "Hello World"
    ID: 26a8147fa04ed9fj2a9ad125c55cee00

    $ clisms -s 26a8147fa04ed9fj2a9ad125c55cee00
    apiMsgId: 26a8147fa04ed9fj2a9ad125c55cee00 charge: 0.8 status: 004
    (received by recipient)

    $ clisms -b
    Credit: 204.900


#### Configuration

Set the Clickatell account configuration parameters in the JSON
formatted configuration named `.clisms.json` in your home directory.
For example:

    {
      "USERNAME":  "foobar",
      "PASSWORD":  "secret",
      "API_ID":    "123456",
      "SENDER_ID": "+64912345678",
      "PHONE_BOOK": {
        "tom":   "+64 21 1234 5678",
        "dick":  "+61 25 1234 567",
        "harry": "+64 9 1234 346"
      }
    }


#### Implementation

The original version this program was [written in Python](https://srackham.wordpress.com/2010/03/23/command-line-sms-script/)
but this version is written in both CoffeeScript (`clisms.coffee`) and
TypeScript (`clisms.ts`) as a learning exercise.  The compiled node
executable `clisms.js` file can be generated from either version (use
the `jake build-coffee` command to compile `clisms.coffee`, `jake
build-ts` command to compile `clisms.ts`.
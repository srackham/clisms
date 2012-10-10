{spawn} = require 'child_process'
path = require 'path'
fs = require 'fs'

DEFAULT_BUILD = 'build.ts'  # The published executable is built from TypeScript.

CS_SRC = path.join __dirname, 'clisms.coffee'
TS_SRC = path.join __dirname, 'clisms.ts'
JS_EXE = path.join __dirname, 'clisms.js'

EXEC_PRINT_OPTS = printStdout: true, printStderr: true

addShebang = (script, linesep = '\n') ->
  fs.writeFileSync script, "#!/usr/bin/env node#{linesep}#{fs.readFileSync script}"

desc 'List Jake tasks.'
task 'default', -> jake.exec ['jake -T'], EXEC_PRINT_OPTS

desc 'Build JavaScript executable from CoffeeScript source.'
task 'build.coffee', ['validate'], ->
  jake.exec ["coffee -c '#{CS_SRC}'"], (-> addShebang JS_EXE), EXEC_PRINT_OPTS

desc 'Build JavaScript executable from TypeScript source.'
task 'build.ts', ['validate'], ->
  jake.exec ["tsc '#{TS_SRC}'"], (-> addShebang JS_EXE), EXEC_PRINT_OPTS

desc 'Validate package.json.'
task 'validate', ->
  try
    JSON.parse fs.readFileSync('package.json')
  catch error
    fail "package.json: invalid JSON: #{error.message}"

desc 'Publish the package to NPM.'
task 'publish', [DEFAULT_BUILD], ->
  jake.exec ['npm publish'], EXEC_PRINT_OPTS

desc 'Commit with message in file COMMIT.'
task 'commit', [DEFAULT_BUILD], ->
  jake.exec ['git commit -a -F COMMIT'], EXEC_PRINT_OPTS

desc 'Push project to github.'
task 'push', ->
  console.log 'pushing to https://github.com/srackham/clisms'
  jake.exec ['git push --tags origin master'], EXEC_PRINT_OPTS

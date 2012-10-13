{spawn} = require 'child_process'
path = require 'path'
fs = require 'fs'

PUBLISHED_BUILD = 'build.ts'  # The published executable is built from TypeScript.

CS_SRC = path.join __dirname, 'clisms.coffee'
TS_SRC = path.join __dirname, 'clisms.ts'
JS_EXE = path.join __dirname, 'clisms.js'
NPM_README = path.join __dirname, 'README.md'
GITHUB_README = path.join __dirname, 'README.asciidoc'

EXEC_PRINT_OPTS = printStdout: true, printStderr: true

addShebang = (script, linesep = '\n') ->
  fs.writeFileSync script, "#!/usr/bin/env node#{linesep}#{fs.readFileSync script}"

desc 'List Jake tasks.'
task 'default', -> jake.exec ['jake -T'], EXEC_PRINT_OPTS

# Used internally to compile JavaScript executable.
# Invoked with compile command string.
task 'build', async: true, ['validate'], (compile_cmd)->
  jake.exec [compile_cmd], ->
        addShebang JS_EXE
        complete()
      , EXEC_PRINT_OPTS

desc 'Build JavaScript executable from CoffeeScript source.'
task 'build.coffee', ->
  jake.Task['build'].invoke "coffee -c '#{CS_SRC}'"

desc 'Build JavaScript executable from TypeScript source.'
task 'build.ts', ->
  jake.Task['build'].invoke "tsc '#{TS_SRC}'"  

desc 'Validate package.json.'
task 'validate', ->
  try
    JSON.parse fs.readFileSync('package.json')
  catch error
    fail "package.json: invalid JSON: #{error.message}"

desc 'Publish the package to npmjs.org'
task 'publish', async: true, [PUBLISHED_BUILD], ->
  # Create stub Markdown README because npmjs.org only handles Markdown.
  fs.writeFileSync NPM_README, "See <https://github.com/srackham/clisms>"
  # Temporarily move the github README out of the way so it's no published.
  fs.renameSync GITHUB_README, 'publish.tmp'
  jake.exec ['npm publish --force'], ->
        fs.renameSync 'publish.tmp', GITHUB_README
        complete()
      , breakOnError: false, printStdout: true, printStderr: true
      
desc 'Commit with message in file COMMIT.'
task 'commit', [PUBLISHED_BUILD], ->
  jake.exec ['git commit -a -F COMMIT'], EXEC_PRINT_OPTS

desc 'Push project to github.'
task 'push', ->
  console.log 'pushing to https://github.com/srackham/clisms'
  jake.exec ['git push --tags origin master'], EXEC_PRINT_OPTS

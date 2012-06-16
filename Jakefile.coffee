{spawn} = require 'child_process'
path = require 'path'
fs = require 'fs'

CS_SRC = path.join __dirname, 'clisms.coffee'
JS_EXE = path.join __dirname, 'clisms.js'

addShebang = (script) ->
  fs.writeFileSync script, "#!/usr/bin/env node\n#{fs.readFileSync script}"

desc 'List Jake tasks.'
task 'default', -> jake.exec ['jake -T'], {printStdout: true}

desc 'Build JavaScript executable.'
task 'build', ['validate'], ->
  jake.exec ["coffee -c '#{CS_SRC}'"], -> addShebang JS_EXE

desc 'Validate package.json.'
task 'validate', ->
  try
    JSON.parse fs.readFileSync('package.json')
  catch error
    fail "package.json: invalid JSON: #{error.message}"

desc 'Publish the package to NPM.'
task 'publish', ['build'], ->
  jake.exec ['npm publish']

desc 'Commit with message in file COMMIT.'
task 'commit', ['build'], ->
  jake.exec ['git commit -a -F COMMIT']

desc 'Push project to github.'
task 'push', ->
  jake.exec ['git push origin master']

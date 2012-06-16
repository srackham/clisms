{spawn} = require 'child_process'
path = require 'path'
fs = require 'fs'

CS_SRC = path.join __dirname, 'clisms.coffee'
JS_EXE = path.join __dirname, 'clisms.js'

shell = (cmd, args, callback) ->
  child = spawn cmd, args
  child.stderr.on 'data', (data) -> console.error data.toString()
  child.stdout.on 'data', (data) -> console.info data.toString()
  child.on 'exit', (code) ->
    if code is 0 then callback?() else fail "#{cmd} #{args.join ' '}"

addShebang = (script) ->
  fs.writeFileSync script, "#!/usr/bin/env node\n#{fs.readFileSync script}"

desc 'Build JavaScript executable.'
task 'build', ['validate'], ->
  shell 'coffee', ['-c', CS_SRC], -> addShebang JS_EXE

desc 'Validate package.json.'
task 'validate', ->
  try
    JSON.parse fs.readFileSync('package.json')
  catch error
    fail "package.json: invalid JSON: #{error.message}"

desc 'Publish the package to NPM.'
task 'publish', ['build'], ->
  shell 'npm', ['publish']

desc 'Commit with message in file COMMIT.'
task 'commit', ['build'], ->
  shell 'git', ['commit', '-a', '-F', 'COMMIT']

desc 'Push project to github.'
task 'push', ->
  shell 'git', ['push', 'origin', 'master']

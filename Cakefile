{spawn} = require 'child_process'
path = require 'path'
fs = require 'fs'

CS_SRC = path.join __dirname, 'clisms.coffee'
JS_EXE = path.join __dirname, 'clisms.js'

die = (message) ->
    console.error "ERROR: #{message}"
    process.exit 1

shell = (cmd, args, callback) ->
  child = spawn cmd, args
  child.stderr.on 'data', (data) -> console.error data.toString()
  child.stdout.on 'data', (data) -> console.info data.toString()
  child.on 'exit', (code) ->
    if code is 0 then callback?() else die "#{cmd} #{args.join ' '}"

addShebang = (script) ->
  fs.writeFileSync script, "#!/usr/bin/env node\n#{fs.readFileSync script}"

task 'build', 'Build JavaScript executable', ->
  invoke 'validate'
  shell 'coffee', ['-c', CS_SRC], -> addShebang JS_EXE

task 'validate', 'Validate package.json', ->
  try
    JSON.parse fs.readFileSync('package.json')
  catch error
    die "package.json: invalid JSON: #{error.message}"

task 'publish', 'Publish the package to NPM', ->
  shell 'npm', ['publish']

task 'commit', 'Commit with message in file COMMIT', ->
  shell 'git', ['commit', '-a', '-F', 'COMMIT']

task 'push', 'Push project to github', ->
  shell 'git', ['push', 'origin', 'master']

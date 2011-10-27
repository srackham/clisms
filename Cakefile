{spawn} = require 'child_process'
path = require 'path'
fs = require 'fs'

CS_SRC = path.join __dirname, 'clisms.coffee'
JS_EXE = path.join __dirname, 'clisms.js'

compile = (callback) ->
  coffee = spawn 'coffee', ['-c', CS_SRC]
  coffee.stderr.on 'data', (data) -> console.error data.toString()
  coffee.stdout.on 'data', (data) -> console.info data.toString()
  coffee.on 'exit', (code) -> callback?() if code is 0

addShebang = ->
  fs.writeFileSync JS_EXE, "#!/usr/bin/env node\n#{fs.readFileSync JS_EXE}"

task 'build', 'Build JavaScript executable', ->
  compile -> addShebang()

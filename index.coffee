child_process = require 'child_process'
_             = require 'lodash'
fs            = require 'fs-extra'
path          = require 'path'

server        = require './lib/server'
env           = require './lib/env'
server        = require 'docker-dashboard-agent-api'
packageJson   = require './package.json'
scripts       = require './lib/scripts'

etcdBaseUrl   = env.assert 'ETCD_BASEURL'
dataDir       = env.assert 'DATA_DIR'
sharedDataDir = env.assert 'SHARED_DATA_DIR'
rootUrl       = env.assert 'ROOT_URL'
targetVlan    = env.assert 'TARGET_VLAN'
syslogUrl     = env.assert 'SYSLOG_URL'
scriptBaseDir = env.assert 'SCRIPT_BASE_DIR'
domain        = env.assert 'DOMAIN'

initialContext =
  etcdCluster: etcdBaseUrl
  dataDir: dataDir
  sharedDataDir: sharedDataDir
  agentUrl: rootUrl
  targetVlan: targetVlan
  syslogUrl: syslogUrl

console.log 'Agent InitialContext', initialContext

agent = server.agent {name: packageJson.name , version: packageJson.version}

writeFile = (scriptPath, script, cb) ->
  fs.writeFile scriptPath, script, {mode: 0o744}, (err) ->
    if err
      console.error err
    else
      console.log "Created file #{scriptPath}" if not err
      cb and cb()

execScript = (scriptPath, cb) ->
  child_process.exec scriptPath, {shell: '/bin/bash'}, (err, stdout, stderr) ->
    console.error err if err
    cb?(stdout: stdout, stderr: stderr)

agent.on 'start', (data) ->
  startScript = scripts.start data, initialContext
  stopScript = scripts.stop data, initialContext

  projectDir = "#{data.instance.options.project}-#{data.instance.name}"
  scriptDir = "#{scriptBaseDir}/#{projectDir}"
  startScriptPath = "#{scriptDir}/start.sh"
  stopScriptPath = "#{scriptDir}/stop.sh"

  fs.mkdir scriptDir, (err) ->
    if not err or err.code is 'EEXIST'
      writeFile stopScriptPath, stopScript
      writeFile startScriptPath, startScript, ->
        execScript startScriptPath, ->
          console.log 'Executed', startScriptPath
    else
      console.error "Cannot make script dir #{scriptDir}", err

agent.on 'stop', (data) ->
  console.log 'stopApp', data
  projectDir = "#{data.instance.options.project}-#{data.instance.name}"
  scriptDir = "#{scriptBaseDir}/#{projectDir}"
  stopScriptPath = "#{scriptDir}/stop.sh"
  execScript stopScriptPath, ->
    console.log 'Executed', stopScriptPath


agent.on '/storage/list', (params, data, callback) ->
  srcpath = path.join dataDir, domain
  callback null, fs.readdirSync(srcpath).filter (file) ->
    fs.statSync(path.join(srcpath, file)).isDirectory()

agent.on '/storage/delete', ({name}, data, callback) ->
  srcpath = path.join dataDir, domain, name
  fs.remove srcpath, callback

agent.on '/storage/create', (params, {name, source}, callback) ->
  targetpath = path.join dataDir, domain, name
  if source
    srcpath = path.join dataDir, domain, source
    fs.copy srcpath, targetpath, callback
  else
    fs.mkdirs targetpath, callback

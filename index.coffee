child_process = require 'child_process'
_             = require 'lodash'
fs            = require 'fs-extra'
path          = require 'path'
request         = require 'request'

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
remotefsUrl   = env.assert 'REMOTEFS_URL'

initialContext =
  etcdCluster: etcdBaseUrl
  dataDir: dataDir
  sharedDataDir: sharedDataDir
  agentUrl: rootUrl
  targetVlan: targetVlan
  syslogUrl: syslogUrl
  remotefsUrl: remotefsUrl

console.log 'Agent InitialContext', initialContext

# remove all storage bucket lock files
child_process.exec "rm #{path.join dataDir, domain, '.*.lock'}"

agent = server.agent {name: packageJson.name , version: packageJson.version}

remoteFs = (cmd, payload, cb) ->
  request
    url: "#{remotefsUrl}/fs/#{cmd}"
    method: 'POST'
    json: payload
    , (err, res, body) ->
      console.error err if err
      cb err, body

writeFile = (scriptPath, script, cb) ->
  fs.writeFile scriptPath, script, {mode: 0o744}, (err) ->
    if err
      console.error err
    else
      console.log "Created file #{scriptPath}" if not err
      cb and cb()

execScript = (scriptPath, cb) ->
  child_process.exec "bash #{scriptPath}", {shell: '/bin/bash'}, (err, stdout, stderr) ->
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
  dirList = fs.readdirSync srcpath
  files = dirList.map (file) ->
    copyLock = ".#{file}.copy.lock"
    deleteLock = ".#{file}.delete.lock"
    sizeLock = ".#{file}.size.lock"
    stat = fs.statSync path.join(srcpath, file)
    if stat.isDirectory()
      name: file
      created: stat.birthtime
      isLocked: copyLock in dirList or deleteLock in dirList
      isSizeLocked: sizeLock in dirList
  .filter (file) -> file?
  callback null, files

agent.on '/datastore/usage', ({name}, data, callback) ->
  console.log "Retrieving usage #{dataDir}"
  child_process.exec "df -B1 #{dataDir} | tail -1 | awk '{ print $2 }{ print $3}{ print $5}'", (err, stdout, stderr) ->
    if err
      console.error err
      callback null, stderr
    totalSize = stdout.split("\n")[0]
    usedSize = stdout.split("\n")[1]
    percentage = stdout.split("\n")[2]
    callback null, { name: dataDir, total: totalSize, used: usedSize, percentage: percentage }

agent.on '/storage/size', ({name}, data, callback) ->
  srcpath = path.join '/', domain, name
  lockFile = path.join dataDir, domain, ".#{name}.size.lock"
  console.log "Retrieving size of #{srcpath}"
  fs.writeFile lockFile, "Retrieving size #{srcpath} ...", ->
    remoteFs 'du', {dir: srcpath}, (err, response) ->
      fs.unlink lockFile, ->
        callback null, { name: name, size: response.size}

agent.on '/storage/delete', ({name}, data, callback) ->
  srcpath = path.join '/', domain, name
  lockFile = path.join dataDir, domain, ".#{name}.delete.lock"
  console.log "Deleting bucket #{srcpath}"
  fs.writeFile lockFile, "Deleting #{srcpath}...", ->
    remoteFs 'rm', {dir: srcpath}, ->
      fs.unlink lockFile, callback

agent.on '/storage/create', (params, {name, source}, callback) ->
  if source
    srcpath = path.join '/', domain, source
    targetpath = path.join '/', domain, name
    lockFile = path.join dataDir, domain, ".#{name}.copy.lock"
    fs.writeFile lockFile, "Copying #{srcpath} to #{targetpath}...", ->
      remoteFs 'cp', {source: srcpath, destination: targetpath}, ->
        fs.unlink lockFile, callback
  else
    targetpath = path.join dataDir, domain, name
    console.log "Creating bucket #{targetpath}"
    fs.mkdirs targetpath, callback

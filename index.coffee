fs            = require 'fs'
child_process = require 'child_process'
topsort       = require 'topsort'
_             = require 'lodash'
handlebars    = require 'handlebars'
fs            = require 'fs-extra'
path          = require 'path'

server        = require './lib/server'
env           = require './lib/env'
helpers       = require './lib/handlebars-helpers'
server        = require 'docker-dashboard-agent-api'
packageJson   = require './package.json'

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

handlebars.registerHelper name, f for name, f of helpers initialContext
startTemplate = handlebars.compile "#{fs.readFileSync './templates/start.hbs'}"
stopTemplate = handlebars.compile "#{fs.readFileSync './templates/stop.hbs'}"

agent = server.agent {name: packageJson.name , version: packageJson.version}

getDependencies = (doc, service) ->
  _.without _.union(
      doc[service]?.links,
      doc[service]?['volumes-from'],
      doc[service]?['volumes_from'],
      doc[service]?['depends_on'],
      [service]
    )
  , undefined

toTopsortArray = (doc) ->
  arr = []
  for service in Object.keys doc when service not in ['name', 'version', 'pic', 'description']
    deps = getDependencies doc, service
    arr = _.union arr, ([service, x] for x in deps)
  arr

resolveParams = (appDef, parameterKey, params)->
  stringified = JSON.stringify appDef
  for key, value of params
    rex = new RegExp "#{parameterKey}#{key}#{parameterKey}", 'g'
    stringified = stringified.replace rex, value
  JSON.parse stringified

createContext = (app, instance, bigboat, ctx) ->
  definition = resolveParams app.definition, app.parameter_key, instance.parameters
  orderedServices = topsort(toTopsortArray definition).reverse()
  ctx = _.merge {}, initialContext,
    project: instance.options.project
    instance: instance.name
    vlan: instance.options?.targetVlan or targetVlan
    dashboardUrl: bigboat.url
    appName: app.name
    appVersion: app.version
    services: []
    total: orderedServices.length
  for service, i in orderedServices
    definition[service].num = i+1
    definition[service].service = service
    ctx.services.push definition[service]
  ctx

writeFile = (scriptPath, script, cb) ->
  fs.writeFile scriptPath, script, {mode: 0o744}, (err) ->
    if err
      console.error err
    else
      console.log "Created file #{scriptPath}" if not err
      cb and cb()

execScript = (scriptPath, cb) ->
  child_process.exec scriptPath, {shell: '/bin/bash'}, (err, stdout, stderr) ->
    console.log err if err
    cb?(stdout: stdout, stderr: stderr)

agent.on 'start', (data) ->
  app = data.app
  instance = data.instance
  bigboat = data.bigboat
  ctx = createContext app, instance, bigboat, initialContext
  startScript = startTemplate ctx
  stopScript = stopTemplate ctx

  projectDir = "#{instance.options.project}-#{instance.name}"
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
  instance = data.instance
  projectDir = "#{instance.options.project}-#{instance.name}"
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

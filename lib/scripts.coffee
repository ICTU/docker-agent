_             = require 'lodash'
handlebars    = require 'handlebars'
fs            = require 'fs'
topsort       = require 'topsort'

helpers       = require './handlebars-helpers'

generateScript = (template) ->
  tpl = handlebars.compile fs.readFileSync(template).toString()
  (data, initialContext) ->
    handlebars.registerHelper name, f for name, f of helpers initialContext
    app = data.app
    instance = data.instance
    bigboat = data.bigboat
    ctx = createContext app, instance, bigboat, initialContext
    tpl ctx

module.exports =
  start: generateScript './templates/start.hbs'
  stop: generateScript './templates/stop.hbs'


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
  ctx = _.merge {}, ctx,
    project: instance.options.project
    instance: instance.name
    storageBucket: instance.options?.storageBucket
    vlan: instance.options?.targetVlan or ctx?.targetVlan
    dashboardUrl: bigboat.url
    statusUrl: bigboat.statusUrl
    appName: app.name
    appVersion: app.version
    services: []
    total: orderedServices.length
  for service, i in orderedServices
    definition[service].num = i+1
    definition[service].service = service
    ctx.services.push definition[service]
  ctx

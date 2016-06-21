topsort = require 'topsort'
_       = require 'lodash'
server  = require './lib/server'

agent = server.agent()

###
app:
  name:
  version:
  definition:
instance:
  name:
  parameters:
  options:
###

toTopsortArray = (doc) ->
  arr = []
  for service in Object.keys doc when service not in ['name', 'version', 'pic', 'description']
    deps = _.union doc[service]?.links, doc[service]?['volumes-from'], doc[service]?['volumes_from'], doc[service]?['depends_on'], [service]
    arr = _.union arr, ([service, x] for x in _.without deps, undefined) #remove undefined from the array
  console.log 'xx', arr
  arr

createContext = (doc, ctx = {}) ->
  orderedServices = topsort(toTopsortArray doc).reverse()
  ctx = _.extend ctx,
    appName: doc.name
    appVersion: doc.version
    services: []
    total: orderedServices.length
  for service, i in orderedServices
    doc[service].num = i+1
    doc[service].service = service
    ctx.services.push doc[service]
  console.log ctx
  ctx


agent.on 'start', (data) ->
  app = data.app
  instance = data.instance
  console.log 'startApp', instance.name
  createContext app.definition


agent.on 'stop', (data) ->
  console.log 'stopApp', data.instance.name

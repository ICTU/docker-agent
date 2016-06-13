monitor       = require '../node-docker-monitor'
request       = require 'request'
_             = require 'lodash'

_.mixin deep: (obj, mapper) ->
  mapper _.mapValues(obj, (v) ->
    if _.isPlainObject(v) then _.deep(v, mapper) else v
  )

replaceDotInKeys = (obj) ->
  _.deep(obj, (x) ->
    _.mapKeys x, (val, key) ->
      if key.indexOf(".") > -1 then key.split('.').join('/') else key
  )

sendRequest = (endpoint, payload) ->
  request
    url: endpoint
    method: 'PUT'
    json: payload
    , (err, res, body) ->
      console.error err if err

publishContainerInfo = (event, container) ->
  if event
    serviceName =event.Actor.Attributes['bigboat/service/name']
    containerName =event.Actor.Attributes['name']
    updateEndpoint = event.Actor.Attributes['bigboat/status/url']
    type = event.Actor.Attributes['bigboat/container/type']
  else
    serviceName = container.Config.Labels['bigboat/service/name']
    containerName = container.Name
    updateEndpoint = container.Config.Labels['bigboat/status/url']
    type = container.Config.Labels['bigboat/container/type']

  console.log "Publishing containerInfo to '#{updateEndpoint}' for '#{containerName}'"
  payload = services: {"#{serviceName}": dockerContainerInfo: {}}
  payload.services[serviceName] = {} unless payload.services[serviceName]
  payload.services[serviceName].dockerContainerInfo[type] = container
  sendRequest updateEndpoint, payload

hasDashboardLabels = (event, container) ->
  if event
    event?.Actor?.Attributes?['bigboat/status/url']
  else
    container?.Config?.Labels?['bigboat/status/url']

module.exports = (dockerServer) ->

  containerHandler = (container) ->
    container = replaceDotInKeys container
    name = container?.Name
    if hasDashboardLabels null, container
      console.log "Processing container '#{name}'"
      publishContainerInfo null, container

  eventHandler = (event, container, docker) ->
    container = replaceDotInKeys container
    name = event.Actor?.Attributes?.name or container?.Name or event.id
    if hasDashboardLabels event, container
      console.log "Received event '#{event.status}' for container '#{name}'"
      publishContainerInfo event, container

  # Process pre-existing containers
  monitor.process_existing_containers containerHandler, dockerServer

  # Listen for docker events
  monitor.listen eventHandler, dockerServer

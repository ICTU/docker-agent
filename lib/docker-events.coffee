monitor       = require '../node-docker-monitor'
request       = require 'request'

sendRequest = (endpoint, payload) ->
  request
    url: endpoint
    method: 'PUT'
    json: payload
    , (err, res, body) ->
      if err
        console.error err
      else
        console.log res.statusCode, body

publishContainerInfo = (container) ->
  serviceName = container.Config.Labels['bigboat/service/name']
  containerName = container.Name
  updateEndpoint = container.Config.Labels['bigboat/status/url']
  type = container.Config.Labels['bigboat/container/type']

  console.log "Publishing containerInfo to '#{updateEndpoint}' for '#{containerName}'"
  payload = services: {"#{serviceName}": dockerContainerInfo: {}}
  payload.services[serviceName] = {} unless payload.services[serviceName]
  payload.services[serviceName].dockerContainerInfo[type] = container
  sendRequest updateEndpoint, payload

hasDashboardLabels = (container) ->
  container?.Config?.Labels?['bigboat/status/url']

module.exports = (dockerServer) ->

  containerHandler = (container) ->
    name = container?.Name
    if hasDashboardLabels container
      console.log "Processing container '#{name}'"
      publishContainerInfo container

  eventHandler = (event, container, docker) ->
    name = event.Actor?.Attributes?.name or container?.Name or event.id
    if hasDashboardLabels container
      console.log "Received event '#{event.status}' for container '#{name}'"
      publishContainerInfo container

  # Process pre-existing containers
  monitor.process_existing_containers containerHandler, dockerServer

  # Listen for docker events
  monitor.listen eventHandler, dockerServer

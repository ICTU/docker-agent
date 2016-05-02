monitor       = require '../node-docker-monitor'
request       = require 'request'

sendRequest = (endpoint, instanceName, payload) ->
  request
    url: "#{endpoint}/api/v1/state/#{instanceName}"
    method: 'PUT'
    json: payload
    , (err, res, body) ->
      if err
        console.error err
      else
        console.log res.statusCode, body

publishContainerInfo = (container) ->
  instanceName = container.Config.Labels['bigboat/instance/name']
  serviceName = container.Config.Labels['bigboat/service/name']
  containerName = container.Name
  state = container.State.Status
  endpoint = container.Config.Labels['bigboat/dashboard/url']
  type = container.Config.Labels['bigboat/container/type']

  console.log "Publishing containerInfo to '#{endpoint}' for '#{containerName}'"
  payload = services: {"#{serviceName}": dockerContainerInfo: {}}
  payload.services[serviceName] = {} unless payload.services[serviceName]
  payload.services[serviceName].dockerContainerInfo[type] = container
  sendRequest endpoint, instanceName, payload

hasDashboardLabels = (container) ->
  container?.Config?.Labels?['bigboat/dashboard/url'] and
  container?.Config?.Labels?['bigboat/instance/name']

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

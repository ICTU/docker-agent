monitor       = require '../node-docker-monitor'
request       = require 'request'

publishContainerInfo = (container) ->
  instanceName = container.Config.Labels['ictu/instance/name']
  serviceName = container.Config.Labels['ictu/service/name']
  containerName = container.Name
  state = container.State.Status
  endpoint = container.Config.Labels['ictu/dashboard/url']
  type = container.Config.Labels['ictu/container/type']

  console.log "Publishing containerInfo to '#{endpoint}' for '#{containerName}'"
  payload = {services: {}}
  payload.services[serviceName] = {} unless payload.services[serviceName]
  if type is 'service'
    payload.services[serviceName] = state: state
  else
    payload.services[serviceName][type] = state
  payload.services[serviceName].dockerContainerInfo = container
  request
    url: "#{endpoint}/api/v1/state/#{instanceName}"
    method: 'PUT'
    json: payload
    , (err, res, body) ->
      if err
        console.error err
      else
        console.log res.statusCode, body

hasDashboardLabels = (container) ->
  container?.Config?.Labels?['ictu/dashboard/url'] and
  container?.Config?.Labels?['ictu/instance/name']

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

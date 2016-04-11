monitor       = require '../node-docker-monitor'
request       = require 'request'

publishState = (container) ->
  instanceName = container.Config.Labels['ictu.instance.name']
  serviceName = container.Config.Labels['ictu.service.name']
  containerName = container.Name
  state = container.State.Status
  endpoint = container.Config.Labels['ictu.dashboard.url']
  type = container.Config.Labels['ictu.container.type']

  console.log "Publishing state '#{state}' to '#{endpoint}' for '#{containerName}'"
  # payload = {services: {}}
  # payload.services[serviceName] = {} unless payload.services[serviceName]
  # if type is 'service'
  #   payload.services[serviceName] = state: state
  # else
  #   payload.services[serviceName][type] = state
  # request
  #   url: "#{endpoint}/api/v1/state/#{instanceName}"
  #   method: 'PUT'
  #   json: payload
  #   , (err, res, body) ->
  #     if err
  #       console.error err
  #     else
  #       console.log res.statusCode, body

module.exports = (dockerSocket) ->

  eventHandler = (event, container, docker) ->
    name = event.Actor?.Attributes?.name or container?.Name or event.id
    console.log "Received event '#{event.status}' for container '#{name}'"
    # if container?.Config?.Labels?['ictu.dashboard.url'] && container?.Config?.Labels?['ictu.instance.name']
    publishState container

  monitor eventHandler, { socketPath: dockerSocket }

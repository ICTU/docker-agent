monitor       = require '../node-docker-monitor'
request       = require 'request'

publishState = (container, instanceName, state, endpoint) ->
  console.log "Publishing state '#{state}' to '#{endpoint}' dashboard"
  payload = {services: {}}
  payload.services[container.Config.Labels['ictu.service.name']] =
    state: state
  request
    url: "#{endpoint}/v1/api/state/#{instanceName}"
    method: 'PUT'
    json: payload
    , (err, res, body) ->
      if err
        console.error err
      else
        console.log res.statusCode, body

module.exports = (dockerSocket) ->

  handlers =
    start: (container) ->
      console.log "Started container", container.Id
      if container.Config?.Labels?['ictu.dashboard.url'] && container.Config?.Labels?['ictu.instance.name']
        publishState container, container.Config.Labels['ictu.instance.name'], container.State.Status, container.Config.Labels['ictu.dashboard.url']
    stop: (container) ->
      console.log "Stopped container", container.Id
      if container.Config?.Labels?['ictu.dashboard.url'] && container.Config?.Labels?['ictu.instance.name']
        publishState container, container.Config.Labels['ictu.instance.name'], container.State.Status, container.Config.Labels['ictu.dashboard.url']


  monitor handlers, { socketPath: dockerSocket }

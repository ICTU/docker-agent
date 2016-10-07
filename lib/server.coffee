
request         = require 'request'
server          = require 'docker-dashboard-agent-api'
url             = require 'url'

dockerHost      = process.env.DOCKER_HOST or 'unix:///var/run/docker.sock'

sendRequest = (endpoint, payload) ->
  console.dir payload
  request
    url: endpoint
    method: 'PUT'
    json: payload
    , (err, res, body) ->
      console.error err if err

publishContainerInfo = (event, container) ->
  if event?.Actor?.Attributes
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

dockerUrl = url.parse dockerHost

console.log dockerUrl

dockerConfig = if dockerUrl.host is '' and dockerUrl.path
  socketPath: dockerUrl.path
else
  host: dockerUrl.hostname
  port: dockerUrl.port

if not dockerConfig.socketPath and (not dockerConfig.host or not dockerConfig.port)
  console.error 'DOCKER_HOST env not properly configured, i got', dockerConfig
  process.exit(1)

console.log 'dockerConfig', dockerConfig

server.docker.processExistingContainers dockerConfig, publishContainerInfo
server.docker.listen dockerConfig, publishContainerInfo

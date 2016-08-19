
request         = require 'request'
server          = require 'docker-dashboard-agent-api'

dockerSocket    = process.env.DOCKER_SOCKET_PATH or '/var/run/docker.sock'
dockerHost      = process.env.DOCKER_HOST

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



# initialize the docker event sourcing
dockerConfig = if dockerHost
  parsedDockerHost = dockerHost.split ':'
  host: parsedDockerHost[0], port: parsedDockerHost[1] or 2375
else
  socketPath: dockerSocket

server.docker.processExistingContainers dockerConfig, publishContainerInfo
server.docker.listen dockerConfig, publishContainerInfo

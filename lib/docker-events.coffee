Docker        = require 'dockerode'
str2stream    = require 'string-to-stream'
JSONStream    = require 'JSONStream'
request       = require 'request'
_             = require 'underscore'

postContainerInspectInfo = (url, serviceName, containerId, inspectInfo) ->
  request
    url: url
    method: "POST"
    json: true
    body: "services.#{serviceName}.dockerInspectInfo": inspectInfo
    , (error, response, body) ->
      if error
        console.error "Error occured while trying to update the dockerInspectInfo for container #{containerId} on url #{url}", error
      else
        console.log "Updated dockerInspectInfo for container #{containerId} on url #{url} "


module.exports = (socketPath) ->

  # use a function cache to update the status of a container
  # multiple events may follow in sequence quickly, avoid
  # expensive operations such as inspecting a container.
  functionCache = {}
  updateContainerStatus = (containerId) ->
    if f = functionCache[containerId]
      f()
    else
      f = ->
        container = docker.getContainer containerId
        container.inspect (err, data) ->
          if err
            console.error "Error occured while inspecting container #{containerId}", err
          else
            url = data.Config?.Labels?._AGENT_DCMNTRY_URL
            service = data.Config?.Labels?._AGENT_SERVICE

            if url and service
              postContainerInspectInfo url, service, containerId, data
            else
              console.warn "Cannot update container dockerInspectInfo, no agent labels found. Container #{containerId}."
        delete functionCache[containerId]

      f = functionCache[containerId] = _.debounce f, 500
      f()

  # Parse json objects from the Docker event stream.
  jsonStream = JSONStream.parse()
  jsonStream.on 'error', (err) -> console.error 'Error while parsing Docker Event stream', err
  jsonStream.on 'data', (event) ->
    console.log "Container #{event.id} changed status to #{event.status}"
    updateContainerStatus event.id

  # Get events from the Docker socket and pass them to a json stream parser.
  docker = new Docker socketPath: socketPath
  docker.getEvents (err, data) ->
    console.error 'Error occured while reading Docker Event from socket', err if err
    data.on 'data', (chunk) -> jsonStream.write chunk


  # Initially, try to update the status of all containers
  docker.listContainers all:true, (err, containers) ->
    containers.forEach (containerInfo) ->
      updateContainerStatus containerInfo.Id

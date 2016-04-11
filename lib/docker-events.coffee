Docker        = require 'dockerode'
JSONStream    = require 'JSONStream'
request       = require 'request'
_             = require 'lodash'

postContainerInspectInfo = (url, containerId, inspectInfo) ->
  request
    url: url
    method: "POST"
    json: true
    body: "dockerInspectInfo": inspectInfo
    , (error, response, body) ->
      if error
        console.error "Error occured while trying to update the dockerInspectInfo for container #{containerId} on url #{url}", error


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
            url = data.Config?.Labels?['iqt.dockerInspectInfoUrl']
            if url
              postContainerInspectInfo url, containerId, data
        delete functionCache[containerId]

      f = functionCache[containerId] = _.debounce f, 1000
      f()

  # Parse json objects from the Docker event stream.
  jsonStream = JSONStream.parse()
  jsonStream.on 'error', (err) -> console.error 'Error while parsing Docker Event stream', err
  jsonStream.on 'data', (event) ->
    updateContainerStatus event.id unless event.status is 'pull'

  # Get events from the Docker socket and pass them to a json stream parser.
  docker = new Docker socketPath: socketPath
  docker.getEvents (err, data) ->
    if err
      console.error 'Error occured while reading Docker Event from socket', err
    else
      data.on 'data', (chunk) -> jsonStream.write chunk


  # Initially, try to update the status of all containers
  docker.listContainers all:true, (err, containers) ->
    if containers?.length
      containers.forEach (containerInfo) ->
        updateContainerStatus containerInfo.Id

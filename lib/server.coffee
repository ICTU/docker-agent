express         = require 'express'
bodyParser      = require 'body-parser'
passport        = require 'passport'
TokenStrategy   = require('passport-token-auth').Strategy
events          = require 'events'

docker_events   = require './docker-events'

module.exports.agent = ->
  httpPort        = process.env.HTTP_PORT or 80
  dockerSocket    = process.env.DOCKER_SOCKET_PATH or '/var/run/docker.sock'
  dockerHost      = process.env.DOCKER_HOST
  dockerPort      = process.env.DOCKER_PORT
  authToken       = process.env.AUTH_TOKEN

  unless authToken
    console.error "AUTH_TOKEN is required!"
    process.exit 1

  eventEmitter = new events.EventEmitter()

  passport.use new TokenStrategy {}, (token, cb) ->
    cb null, authToken == token

  app = express()
  app.use passport.initialize()
  app.use bodyParser.json()
  app.use bodyParser.urlencoded extended: false
  authenticate = passport.authenticate('token', { session: false })

  run = (action) -> (req, res) ->
    data = req.body
    eventEmitter.emit action, data
    res.status(200).end('thanks')

  app.post '/app/install-and-run', authenticate, (req, res) ->
    data = req.body
    if data.app and data.instance
      eventEmitter.emit 'start', data
      res.status(200).end('thanks')
    else res.status(422).end 'appInfo not provided'

  app.post '/app/start', authenticate, run('start')
  app.post '/app/stop', authenticate, run('stop')

  app.get '/ping', (req, res) -> res.end('pong')

  app.get '/version', (req, res) -> res.end (require './package.json').version

  server = app.listen httpPort, ->
    host = server.address().address
    port = server.address().port
    console.log 'Listening on http://%s:%s', host, port

  # initialize the docker event sourcing
  if dockerHost && dockerPort
    docker_events {host: dockerHost, port: dockerPort}
  else
    docker_events {socketPath: dockerSocket}

  eventEmitter

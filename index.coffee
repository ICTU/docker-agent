express         = require 'express'
bodyParser      = require 'body-parser'
passport        = require 'passport'
TokenStrategy   = require('passport-token-auth').Strategy
fs              = require 'fs'
_               = require 'lodash'
child_process   = require 'child_process'

docker_events   = require './lib/docker-events'

httpPort        = process.env.HTTP_PORT or 80
baseDir         = process.env.BASE_DIR or '/tmp'
dockerSocket    = process.env.DOCKER_SOCKET_PATH or '/var/run/docker.sock'
dockerHost      = process.env.DOCKER_HOST
dockerPort      = process.env.DOCKER_PORT
authToken       = process.env.AUTH_TOKEN

unless authToken
  console.error "AUTH_TOKEN is required!"
  process.exit 1

console.log
  baseDir: baseDir

passport.use new TokenStrategy {}, (token, cb) ->
  cb null, authToken == token

app = express()
app.use passport.initialize()
app.use bodyParser.json()
app.use bodyParser.urlencoded extended: false
authenticate = passport.authenticate('token', { session: false })

writeFile = (scriptPath, script, cb) ->
  fs.writeFile scriptPath, script, (err) ->
    if err
      console.error err
    else
      console.log "Created file #{scriptPath}" if not err
      cb and cb()

run = (action) -> (req, res) ->
  data = req.body
  dir = data.dir
  scriptDir = "/#{baseDir}/#{dir}"
  scriptPath = "/#{scriptDir}/#{action}.sh"

  if dir
    fs.exists scriptPath, (exists) ->
      if exists
        execScript res, scriptPath, (result) ->
          res.end JSON.stringify result
      else
        console.error "#{scriptPath} does not exist!"
        res.status(404).end("#{scriptPath} does not exist!")
  else
    res.status(422).end('Please, provide all required parameters: dir')


execScript = (res, scriptPath, cb) ->
  child_process.exec "bash #{scriptPath}", {}, (err, stdout, stderr) ->
    console.log err if err
    cb?(stdout: stdout, stderr: stderr)


app.post '/app/install-and-run', authenticate, (req, res) ->
  data = req.body
  startScript = data.startScript
  stopScript = data.stopScript
  dir = data.dir
  scriptDir = "/#{baseDir}/#{dir}"
  startScriptPath = "/#{scriptDir}/start.sh"
  stopScriptPath = "/#{scriptDir}/stop.sh"

  if dir and startScript and stopScript
    fs.mkdir scriptDir, (err) ->
      if not err or err.code is 'EEXIST'
        writeFile stopScriptPath, stopScript
        writeFile startScriptPath, startScript, ->
          execScript res, startScriptPath, (result) ->
            res.end JSON.stringify result
      else
        console.error "Cannot make script dir #{scriptDir}", err
        res.status(500).end "An error occured: #{err}"
  else
    res.status(422).end('Please, provide all required parameters: dir, startScript, stopScript')

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

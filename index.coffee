express     = require 'express'
bodyParser  = require 'body-parser'
ssh         = require 'ssh2-connect'
fs          = require 'ssh2-fs'

httpPort    = process.env.HTTP_PORT or 80
baseDir     = process.env.BASE_DIR or '/tmp'
hostAddr        = process.env.HOST_ADDR or '172.17.42.1'
username    = process.env.USER or 'core'
privateKeyPath = process.env.PRIVATE_KEY or '~/.ssh/id_rsa'

console.log
  baseDir: baseDir
  hostAddr: hostAddr
  username: username
  privateKeyPath: privateKeyPath

app = express()
app.use bodyParser.json()
app.use bodyParser.urlencoded extended: false

withSsh = (cb) ->
  ssh {host: hostAddr, username: username, privateKeyPath: privateKeyPath}, (err, sess) ->
    if err
      console.error err
    else
      cb and cb(sess)

exec = (sess, scriptPath, cb) ->
  sess.exec "sudo bash #{scriptPath}", (err, stream) ->
    if err
      console.error err
    else
      console.log "Executing #{scriptPath}"
      console.log "------------------------------------------------------------"
      cb and cb(stream)
      stream.on 'data', (data) ->
        console.log "#{data}"

writeFile = (sess, scriptPath, script, cb) ->
  fs.writeFile sess, scriptPath, script, (err) ->
    if err
      console.error err
    else
      console.log "Created file #{scriptPath}" if not err
      cb and cb()

pipeTo = (res) -> (stream) ->
  stream.on 'data', (data) -> res.write "#{data}"
  stream.stderr.on 'data', (data) -> res.write "ERROR: #{data}"
  stream.on 'close', -> res.end()

run = (action) -> (req, res) ->
  data = req.body
  dir = data.dir
  scriptDir = "/#{baseDir}/#{dir}"
  scriptPath = "/#{scriptDir}/#{action}.sh"

  if dir
    withSsh (sess) ->
      fs.mkdir sess, scriptDir, (err) ->
        if not err or err.code is 'EEXIST'
          fs.exists sess, scriptPath, (err, exists) ->
            if err
              console.error err
            else
              if exists
                exec sess, scriptPath, pipeTo(res)
              else
                console.error "#{scriptPath} does not exist!"
  else
    res.status(422).end('Please, provide all required parameters: dir')

app.post '/app/install-and-run', (req, res) ->
  data = req.body
  startScript = data.startScript
  stopScript = data.stopScript
  dir = data.dir
  scriptDir = "/#{baseDir}/#{dir}"
  startScriptPath = "/#{scriptDir}/start.sh"
  stopScriptPath = "/#{scriptDir}/stop.sh"

  if dir and startScript and stopScript
    withSsh (sess) ->
      fs.mkdir sess, scriptDir, (err) ->
        if not err or err.code is 'EEXIST'
          writeFile sess, stopScriptPath, stopScript
          writeFile sess, startScriptPath, startScript,  ->
            exec sess, startScriptPath, pipeTo(res)
        else
          console.error "Cannot make script dir #{scriptDir}", err
  else
    res.status(422).end('Please, provide all required parameters: dir, startScript, stopScript')

app.post '/app/start', run('start')
app.post '/app/stop', run('stop')

server = app.listen httpPort, ->
  host = server.address().address
  port = server.address().port
  console.log 'Listening on http://%s:%s', host, port

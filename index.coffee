express     = require 'express'
bodyParser  = require 'body-parser'
ssh         = require 'ssh2-connect'
fs          = require 'ssh2-fs'

httpPort    = process.env.HTTP_PORT or 80
baseDir     = process.env.BASE_DIR or '/tmp'
host        = process.env.HOST_ADDR or '172.17.42.1'
username    = process.env.USER or 'core'
privateKeyPath = process.env.PRIVATE_KEY or '~/.ssh/id_rsa'

app = express()
app.use bodyParser.json()
app.use bodyParser.urlencoded extended: false

withSsh = (cb) ->
  ssh host: host, username: username, privateKeyPath: privateKeyPath, cb

exec = (sess, scriptPath) ->
  sess.exec "bash #{scriptPath}", (err, stream) ->
    console.log err if err
    console.log "Executing #{scriptPath}"
    stream.on 'data', (data) ->
      console.log "#{data}"

writeFile = (sess, scriptPath, script, cb) ->
  fs.writeFile sess, scriptPath, script, (err) ->
    console.log "Created file #{scriptPath}" if not err
    console.error err if err
    cb and cb()

run = (action) -> (req, res) ->
  data = req.body
  dir = data.dir
  scriptDir = "/#{baseDir}/#{dir}"
  scriptPath = "/#{scriptDir}/#{action}.sh"

  if dir
    withSsh (err, sess) ->
      fs.mkdir sess, scriptDir, (err) ->
        if not err or err.code is 'EEXIST'
          fs.exists sess, scriptPath, (err, exists) ->
            console.error err if err
            if exists
              exec sess, scriptPath
            else
              console.error "#{scriptPath} does not exist!"

    res.end('Thank you, come again!')
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
    withSsh (err, sess) ->
      fs.mkdir sess, scriptDir, (err) ->
        if not err or err.code is 'EEXIST'
          writeFile sess, stopScriptPath, stopScript
          writeFile sess, startScriptPath, startScript,  ->
            exec sess, startScriptPath
        else
          console.error "Cannot make script dir #{scriptDir}", err

    res.end('Thank you, come again!')
  else
    res.status(422).end('Please, provide all required parameters: dir, startScript, stopScript')

app.post '/app/start', run('start')
app.post '/app/stop', run('stop')

server = app.listen httpPort, ->
  host = server.address().address
  port = server.address().port
  console.log 'Listening on http://%s:%s', host, port

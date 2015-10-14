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

app.post '/app/install-and-run', (req, res) ->
  data = req.body
  startScript = data.startScript
  stopScript = data.stopScript
  dir = data.dir
  scriptDir = "/#{baseDir}/#{dir}"
  startScriptPath = "/#{scriptDir}/start.sh"
  stopScriptPath = "/#{scriptDir}/stop.sh"

  if dir and startScript and stopScript
    ssh host: host, username: username, privateKeyPath: privateKeyPath, (err, sess) ->
      fs.mkdir sess, scriptDir, (err) ->
        if not err or err.code is 'EEXIST'
          fs.writeFile sess, stopScriptPath, stopScript, (err) ->
            console.log "Created file #{stopScriptPath}" if not err
            console.log err if err

          fs.writeFile sess, startScriptPath, startScript, (err) ->
            console.log "Created file #{startScriptPath}" if not err
            console.log err if err

            sess.exec "bash #{startScriptPath}", (err, stream) ->
              console.log err if err
              stream.on 'data', (data) ->
                console.log 'Executing script...'
                console.log "#{data}"
        else
          console.error 'Cannot make script dir.', err

    res.end('Thank you, come again!')
  else
    res.status(422).end('Please, provide all required parameters: dir, startScript, stopScript')

server = app.listen httpPort, ->
  host = server.address().address
  port = server.address().port
  console.log 'Listening on http://%s:%s', host, port

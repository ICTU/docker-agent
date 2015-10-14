express     = require 'express'
bodyParser  = require 'body-parser'
ssh         = require 'ssh2-connect'
fs          = require 'ssh2-fs'

httpPort    = process.env.HTTP_PORT or 80
baseDir     = process.env.BASE_DIR or '/tmp'

app         = express()


app.use bodyParser.urlencoded extended: false

app.post '/app/install-and-run', (req, res) ->
  data = req.body
  startScript = data.startScript
  dir = data.dir
  scriptDir = "/#{baseDir}/#{dir}"
  startScriptPath = "/#{scriptDir}/start.sh"

  ssh host: '172.17.42.1', username: 'jepee', privateKeyPath: '/home/jepee/.ssh/id_rsa', (err, sess) ->
    fs.mkdir sess, scriptDir, (err) ->
      if not err or err.code is 'EEXIST'
        fs.writeFile sess, startScriptPath, startScript, (err) ->
          console.log 'file written' if not err
          console.log err if err

          sess.exec "bash #{startScriptPath}", (err, stream) ->
            console.log err if err
            stream.on 'data', (data) ->
              console.log 'data', "#{data}"
      else
        console.error 'Cannot make script dir', err


  res.end('thank you, come again...')
  console.log data


server = app.listen httpPort, ->
  host = server.address().address
  port = server.address().port
  console.log 'Web listening on http://%s:%s', host, port

assert = require 'assert'
fs = require 'fs'
scripts = require '../lib/scripts'

describe 'Start script', ->
  it 'should be correctly generated', ->
    actual = scripts.start test.data, test.context
    assert.equal actual.trim(),test.expected.start.trim()

describe 'Stop script', ->
  it 'should be correctly generated', ->
    actual = scripts.stop test.data, test.context
    assert.equal actual.trim(), test.expected.stop.trim()

test =
  data:
    'dir': 'infra-kong'
    'app':
      'name': 'kong'
      'version': '0.5.2'
      'definition':
        'name': 'kong'
        'version': '0.5.2'
        'cassandra': 'image': 'mashape/cassandra'
        'www':
          'image': 'mashape/kong:0.5.2'
          'links': [ 'cassandra' ]
          'entrypoint': 'bash'
          'endpoint': ':8080?test=ttt'
          'map_docker': true
      'parameter_key': '_#_'
      '_definition':
        'name': 'kong'
        'version': '0.5.2'
        'www':
          'image': 'mashape/kong:0.5.2'
          'links': [ 'cassandra' ]
          'entrypoint': 'bash'
        'cassandra': 'image': 'mashape/cassandra'
    'instance':
      'name': 'kong'
      'options':
        'dataDir': '/local/data'
        'storageBucket': 'kong'
        'project': 'infra'
      'parameters': 'tags': null
    'bigboat':
      'url': 'http://localhost:3000/'
      'statusUrl': 'http://localhost:3000/api/v1/state/kong'

  context:
    etcdCluster: 'http://etcd1.isd.ictu:4001'
    dataDir: '/local/data'
    sharedDataDir: '/mnt/data'
    agentUrl: 'http://0.0.0.0:8080'
    targetVlan: '3080'
    syslogUrl: 'udp://logstash.isd.ictu:5454'

  expected:
    start: (fs.readFileSync 'test/data/start.sh').toString()
    stop: (fs.readFileSync 'test/data/stop.sh').toString()

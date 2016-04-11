/**

 docker events example:

 {"status":"die","id":"81cde361ec7b069cc1ee32a4660176306a2b1d3a3eb52f96f17380f10e75d2e2","from":"m4all-next:15-0511-1104","time":1431403163}
 {"status":"start","id":"81cde361ec7b069cc1ee32a4660176306a2b1d3a3eb52f96f17380f10e75d2e2","from":"m4all-next:15-0511-1104","time":1431403163}
 ...

 */

var Docker = require('dockerode');

module.exports = function (handler, opts) {
    var docker;
    if (opts) {
        if (opts.listContainers) {
            docker = opts;
        } else {
            docker = new Docker(opts);
        }
    } else {
        docker = new Docker({ socketPath: '/var/run/docker.sock' });
    }

    var trackedEvents = ['create', 'restart', 'start', 'destroy', 'die', 'kill', 'stop', 'oom'];

    function handleEvent(event, handler) {
      docker.getContainer(event.id).inspect(function (err,data) {
        handler && handler(data, docker);
      });
    }

    function processDockerEvent(event, stop) {
      if (trackedEvents.indexOf(event.status) !== -1) {
        handleEvent(event, handler[event.status]);
      }
    }

    // start monitoring docker events
    docker.getEvents(function (err, data) {
        if (err) {
            return console.log('Error getting docker events: %s', err.message, err);
        }

        data.on('data', function (chunk) {
            var lines = chunk.toString().replace(/\n$/, "").split('\n');
            lines.forEach(function (line) {
                try {
                    if (line) {
                        processDockerEvent(JSON.parse(line));
                    }
                } catch (e){
                    console.log('Error reading Docker event: %s', e.message, line);
                }
            });
        });
    });


};

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
        handler && handler(event, data, docker);
      });
    }

    function processDockerEvent(event, stop) {
      if (trackedEvents.indexOf(event.status) !== -1) {
        handleEvent(event, handler);
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

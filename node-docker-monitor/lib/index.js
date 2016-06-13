var Docker = require('dockerode');

module.exports = {
  process_existing_containers: function (handler, opts) {
    var docker = new Docker(opts);

    var i = 10;
    console.log("Processing all pre-existing containers");
    docker.listContainers({all: 1}, function (err, containers) {
      containers.forEach(function (containerInfo) {
        docker.getContainer(containerInfo.Id).inspect(function (err, data) {
          if (err && !data) {
            console.error("Failed to inspect container: ", err);
          } else {
            setTimeout(function() {handler && handler(data);}, i)
            i = i + 10;
          }
        });
      });
    });
  },

  listen: function (handler, opts) {
    var docker = new Docker(opts);

    var trackedEvents = ['start', 'die', 'destroy'];

    function handleEvent(event, handler) {
      setTimeout(function() {
        docker.getContainer(event.id).inspect(function (err,data) {
          if (err) {
            console.error("Failed to inspect container: ", err);
            handler && handler(event, {}, docker);
          } else {
            handler && handler(event, data, docker);
          }
        });
      }, 500);
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
  }
};

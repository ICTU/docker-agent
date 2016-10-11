set -x

syslogProto=`echo 'udp://logstash.isd.ictu:5454' | grep -oE '(^[a-z]+):' | grep -oE '[a-z]+'`
syslogHost=`echo 'udp://logstash.isd.ictu:5454' | grep -oE '(//.+):' | cut -c3-  | rev | cut -c2- | rev`
syslogPort=`echo 'udp://logstash.isd.ictu:5454' | grep -oE '(:[0-9]+)' | cut -c2-`

ID="$(cat /proc/sys/kernel/random/uuid)"

exec 1> >(awk -v id=$ID '{ print id, "=>", $0; fflush(); }' | ncat $syslogHost --$syslogProto $syslogPort) 2>&1

#
# GENERAL STATE CLEANUP AND CONFIGURATION+
#
# Root data directory is /local/data
#
PROJECT="infra"
APPNAME="kong"
INSTANCE="kong"
ETCD_CLUSTER="http://etcd1.isd.ictu:4001"

vlan="3080"

TOTAL_STEPS=$(((2*3)+2))
STEP=1


DASHBOARD_URL=http://localhost:3000/api/v1/state/kong


curl -XPUT -sS $DASHBOARD_URL -H "Content-Type: application/json" -d "{ \
	\"meta\": { \
		\"state\": \"loading\", \
		\"totalSteps\": \"$TOTAL_STEPS\", \
		\"progress\": \"$STEP\", \
		\"id\": \"$ID\" \
	} \
}"


# PULL ALL IMAGES
curl -XPUT -sS $DASHBOARD_URL -H "Content-Type: application/json" -d '{
	"meta": {
		"state": "pulling"
	}
}'

echo "Pulling image mashape/cassandra..."
curl -XPUT -sS $DASHBOARD_URL -H "Content-Type: application/json" -d "{ \
	\"meta\": { \
		\"stateDescription\": \"Pulling image mashape/cassandra\" \
	} \
}"

docker pull mashape/cassandra

echo "Done pulling image mashape/cassandra"
STEP=$((STEP+1))
curl -XPUT -sS $DASHBOARD_URL -H "Content-Type: application/json" -d "{ \
	\"meta\": { \
		\"progress\": \"$STEP\" \
	} \
}"

echo "Pulling image mashape/kong:0.5.2..."
curl -XPUT -sS $DASHBOARD_URL -H "Content-Type: application/json" -d "{ \
	\"meta\": { \
		\"stateDescription\": \"Pulling image mashape/kong:0.5.2\" \
	} \
}"

docker pull mashape/kong:0.5.2

echo "Done pulling image mashape/kong:0.5.2"
STEP=$((STEP+1))
curl -XPUT -sS $DASHBOARD_URL -H "Content-Type: application/json" -d "{ \
	\"meta\": { \
		\"progress\": \"$STEP\" \
	} \
}"


# ACTIVATE ALL SERVICES


DOCKERNAME="cassandra-$PROJECT-$INSTANCE"
DOCKERNETNAME="net-$DOCKERNAME"
DOCKERSSHDNAME="sshd-$DOCKERNAME"

curl -XPUT -sS $DASHBOARD_URL -H "Content-Type: application/json" -d "{ \
	\"meta\": { \
		\"state\": \"activating\", \
		\"stateDescription\": \"Preparing network for cassandra\" \
	} \
}"

echo "Preparing network for service cassandra"

#
# Remove any left-behind instances
#
docker kill $DOCKERNETNAME 2>/dev/null
docker rm $DOCKERNETNAME 2>/dev/null
docker kill $DOCKERNAME 2>/dev/null
docker rm $DOCKERNAME 2>/dev/null
docker kill $DOCKERSSHDNAME 2>/dev/null
docker rm $DOCKERSSHDNAME 2>/dev/null
#
# Prepare the volumes
#


#
# Prepare the network
#
links=""

docker run \
--restart=always \
--name $DOCKERNETNAME \
--net=none \
--dns-search=kong.infra.ictu \
-h cassandra.kong.infra.ictu \
--label bigboat/dashboard/url=http://localhost:3000/ \
--label bigboat/status/url=http://localhost:3000/api/v1/state/kong \
--label bigboat/project=infra \
--label bigboat/application/name=kong \
--label bigboat/instance/name=kong \
--label bigboat/service/name=cassandra \
--label bigboat/container/type=net \
 \
-e pipework_cmd="@VLT_NIC@ -i eth0 @CONTAINER_NAME@ dhclient @${vlan}" \
-d www.docker-registry.isd.ictu:5000/pipes:1

while [ 1 ]; do
  pubip=$(docker exec $DOCKERNETNAME ifconfig eth0 | grep "inet addr:" | awk '{print $2}' | awk -F: '{print $2}');
  if [[ $pubip ]]; then
    echo "ip=$pubip"
    break;
  else
    echo "waiting on IP from DHCP for $DOCKERNETNAME"
    sleep 5
  fi
done
STEP=$((STEP+1))
curl -XPUT -sS $DASHBOARD_URL -H "Content-Type: application/json" -d "{ \
	\"meta\": { \
		\"progress\": \"$STEP\" \
	} \
}"

#
# Start the service container
#
curl -XPUT -sS $DASHBOARD_URL -H "Content-Type: application/json" -d '{
	"meta": {"stateDescription": "Activating service cassandra"}
}'

BIGBOAT_PROJECT=infra
BIGBOAT_APPLICATION_NAME=kong
BIGBOAT_INSTANCE_NAME=kong
BIGBOAT_SERVICE_NAME=cassandra

docker run -d \
--restart=always \
--name $DOCKERNAME \
--net="container:$DOCKERNETNAME" \
--label bigboat/dashboard/url=http://localhost:3000/ \
--label bigboat/status/url=http://localhost:3000/api/v1/state/kong \
--label bigboat/project=infra \
--label bigboat/application/name=kong \
--label bigboat/instance/name=kong \
--label bigboat/service/name=cassandra \
--label bigboat/container/type=service \
-e BIGBOAT_PROJECT=infra \
-e BIGBOAT_APPLICATION_NAME=kong \
-e BIGBOAT_INSTANCE_NAME=kong \
-e BIGBOAT_SERVICE_NAME=cassandra \
 \
 \
 \
 \
 \
 \
 \
 \
 \
-v /etc/localtime:/etc/localtime:ro mashape/cassandra  > /dev/null


#
# Publish info about the container
#
hostname="cassandra.$INSTANCE.$PROJECT.ictu"
myip=$(docker exec $DOCKERNETNAME ifconfig eth0 | grep "inet addr:" | awk '{print $2}' | awk -F: '{print $2}')
ports=$(docker inspect -f '{{range $p, $conf := .Config.ExposedPorts}}{{$p}} {{end}}' mashape/cassandra)
cid=$(docker inspect -f '{{.Id}}' $DOCKERNAME)

curl -XPUT -sS $DASHBOARD_URL -H "Content-Type: application/json" -d "{ \
	\"services\": { \
			\"cassandra\": { \
				\"ip\": \"$myip\", \
				\"hostname\": \"$hostname\", \
				\"ports\": \"$ports\", \
				\"dockerContainerName\": \"$DOCKERNAME\", \
				\"dockerContainerId\": \"$cid\" \
			} \
		} \
}"



STEP=$((STEP+1))
curl -XPUT -sS $DASHBOARD_URL -H "Content-Type: application/json" -d "{ \
	\"meta\": { \
		\"progress\": \"$STEP\" \
	} \
}"

DOCKERNAME="www-$PROJECT-$INSTANCE"
DOCKERNETNAME="net-$DOCKERNAME"
DOCKERSSHDNAME="sshd-$DOCKERNAME"

curl -XPUT -sS $DASHBOARD_URL -H "Content-Type: application/json" -d "{ \
	\"meta\": { \
		\"state\": \"activating\", \
		\"stateDescription\": \"Preparing network for www\" \
	} \
}"

echo "Preparing network for service www"

#
# Remove any left-behind instances
#
docker kill $DOCKERNETNAME 2>/dev/null
docker rm $DOCKERNETNAME 2>/dev/null
docker kill $DOCKERNAME 2>/dev/null
docker rm $DOCKERNAME 2>/dev/null
docker kill $DOCKERSSHDNAME 2>/dev/null
docker rm $DOCKERSSHDNAME 2>/dev/null
#
# Prepare the volumes
#


#
# Prepare the network
#
links=""
links="$links--link net-cassandra-$PROJECT-$INSTANCE:cassandra "

docker run \
--restart=always \
--name $DOCKERNETNAME \
--net=none \
--dns-search=kong.infra.ictu \
-h www.kong.infra.ictu \
--label bigboat/dashboard/url=http://localhost:3000/ \
--label bigboat/status/url=http://localhost:3000/api/v1/state/kong \
--label bigboat/project=infra \
--label bigboat/application/name=kong \
--label bigboat/instance/name=kong \
--label bigboat/service/name=www \
--label bigboat/container/type=net \
 \
-e pipework_cmd="@VLT_NIC@ -i eth0 @CONTAINER_NAME@ dhclient @${vlan}" \
-d www.docker-registry.isd.ictu:5000/pipes:1

while [ 1 ]; do
  pubip=$(docker exec $DOCKERNETNAME ifconfig eth0 | grep "inet addr:" | awk '{print $2}' | awk -F: '{print $2}');
  if [[ $pubip ]]; then
    echo "ip=$pubip"
    break;
  else
    echo "waiting on IP from DHCP for $DOCKERNETNAME"
    sleep 5
  fi
done
STEP=$((STEP+1))
curl -XPUT -sS $DASHBOARD_URL -H "Content-Type: application/json" -d "{ \
	\"meta\": { \
		\"progress\": \"$STEP\" \
	} \
}"

#
# Start the service container
#
curl -XPUT -sS $DASHBOARD_URL -H "Content-Type: application/json" -d '{
	"meta": {"stateDescription": "Activating service www"}
}'

BIGBOAT_PROJECT=infra
BIGBOAT_APPLICATION_NAME=kong
BIGBOAT_INSTANCE_NAME=kong
BIGBOAT_SERVICE_NAME=www

docker run -d \
--restart=always \
--name $DOCKERNAME \
--net="container:$DOCKERNETNAME" \
--label bigboat/dashboard/url=http://localhost:3000/ \
--label bigboat/status/url=http://localhost:3000/api/v1/state/kong \
--label bigboat/project=infra \
--label bigboat/application/name=kong \
--label bigboat/instance/name=kong \
--label bigboat/service/name=www \
--label bigboat/container/type=service \
-e BIGBOAT_PROJECT=infra \
-e BIGBOAT_APPLICATION_NAME=kong \
-e BIGBOAT_INSTANCE_NAME=kong \
-e BIGBOAT_SERVICE_NAME=www \
 \
 \
 \
 \
--entrypoint=bash \
 \
 \
 \
 \
-v /etc/localtime:/etc/localtime:ro mashape/kong:0.5.2  > /dev/null


#
# Publish info about the container
#
hostname="www.$INSTANCE.$PROJECT.ictu"
myip=$(docker exec $DOCKERNETNAME ifconfig eth0 | grep "inet addr:" | awk '{print $2}' | awk -F: '{print $2}')
ports=$(docker inspect -f '{{range $p, $conf := .Config.ExposedPorts}}{{$p}} {{end}}' mashape/kong:0.5.2)
cid=$(docker inspect -f '{{.Id}}' $DOCKERNAME)

curl -XPUT -sS $DASHBOARD_URL -H "Content-Type: application/json" -d "{ \
	\"services\": { \
			\"www\": { \
				\"ip\": \"$myip\", \
				\"hostname\": \"$hostname\", \
				\"ports\": \"$ports\", \
				\"dockerContainerName\": \"$DOCKERNAME\", \
				\"dockerContainerId\": \"$cid\" \
			} \
		} \
}"


curl -XPUT -sS $DASHBOARD_URL -H "Content-Type: application/json" -d "{ \
	\"services\": { \
			\"www\": { \
				\"endpoint\": \":8080?test=ttt\" \
			} \
		} \
}"

STEP=$((STEP+1))
curl -XPUT -sS $DASHBOARD_URL -H "Content-Type: application/json" -d "{ \
	\"meta\": { \
		\"progress\": \"$STEP\" \
	} \
}"


STEP=$((STEP+1))
curl -XPUT -sS $DASHBOARD_URL -H "Content-Type: application/json" -d "{ \
	\"meta\": { \
		\"progress\": \"$STEP\", \
		\"stateDescription\": \"Checking application health\" \
	} \
}"
DOCKERNAME="cassandra-$PROJECT-$INSTANCE"
DOCKERNETNAME="net-$DOCKERNAME"
if [ "$(docker ps | grep '\s'$DOCKERNAME)" ]; then
	echo "SUCCESS: $DOCKERNAME is running";
else
	echo "FAILURE: $DOCKERNAME is not running";
fi
if [ "$(docker ps | grep '\s'$DOCKERNETNAME)" ]; then
	echo "SUCCESS: network for $DOCKERNAME is running";
else
	echo "FAILURE: network for $DOCKERNAME is not running";
fi
DOCKERNAME="www-$PROJECT-$INSTANCE"
DOCKERNETNAME="net-$DOCKERNAME"
if [ "$(docker ps | grep '\s'$DOCKERNAME)" ]; then
	echo "SUCCESS: $DOCKERNAME is running";
else
	echo "FAILURE: $DOCKERNAME is not running";
fi
if [ "$(docker ps | grep '\s'$DOCKERNETNAME)" ]; then
	echo "SUCCESS: network for $DOCKERNAME is running";
else
	echo "FAILURE: network for $DOCKERNAME is not running";
fi

sleep 2

curl -XPUT -sS $DASHBOARD_URL -H "Content-Type: application/json" -d "{ \
	\"meta\": { \
		\"state\": \"active\", \
		\"stateDescription\": \"Active\" \
	} \
}"

echo "Application started"

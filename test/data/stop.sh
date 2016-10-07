PROJECT="infra"
APPNAME="kong"
INSTANCE="kong"
TOTAL_STEPS=$(((2*2)+1))
STEP=0

DASHBOARD_URL=http://localhost:3000//api/v1/state/$INSTANCE

curl -XPUT -sS $DASHBOARD_URL -H "Content-Type: application/json" -d "{ \
	\"meta\": { \
		\"state\": \"stopping\", \
		\"totalSteps\": \"$TOTAL_STEPS\", \
		\"progress\": \"$STEP\" \
	} \
}"

  DOCKERNAME="www-$PROJECT-$INSTANCE"
  DOCKERNETNAME="net-$DOCKERNAME"
  DOCKERSSHDNAME="sshd-$DOCKERNAME"

  myip=$(docker exec $DOCKERNETNAME ifconfig eth1 | grep "inet addr:" | awk '{print $2}' | awk -F: '{print $2}')
  curl -XPUT -sS $DASHBOARD_URL -H "Content-Type: application/json" -d "{ \
  	\"meta\": { \
  		\"stateDescription\": \"Stopping network for www\" \
  	} \
  }"

  STEP=$((STEP+1))
  curl -XPUT -sS $DASHBOARD_URL -H "Content-Type: application/json" -d "{ \
    \"meta\": { \
      \"progress\": \"$STEP\" \
    } \
  }"

  docker stop -t 5 $DOCKERNETNAME
  docker rm $DOCKERNETNAME

  curl -XPUT -sS $DASHBOARD_URL -H "Content-Type: application/json" -d "{ \
    \"meta\": { \
      \"stateDescription\": \"Stopping service www\", \
      \"progress\": \"$STEP\" \
    } \
  }"
  STEP=$((STEP+1))
  curl -XPUT -sS $DASHBOARD_URL -H "Content-Type: application/json" -d "{ \
    \"meta\": { \
      \"progress\": \"$STEP\" \
    } \
  }"
  docker stop -t 10 $DOCKERSSHDNAME
  docker rm $DOCKERSSHDNAME
  docker stop -t 30 $DOCKERNAME
  docker rm $DOCKERNAME

  DOCKERNAME="cassandra-$PROJECT-$INSTANCE"
  DOCKERNETNAME="net-$DOCKERNAME"
  DOCKERSSHDNAME="sshd-$DOCKERNAME"

  myip=$(docker exec $DOCKERNETNAME ifconfig eth1 | grep "inet addr:" | awk '{print $2}' | awk -F: '{print $2}')
  curl -XPUT -sS $DASHBOARD_URL -H "Content-Type: application/json" -d "{ \
  	\"meta\": { \
  		\"stateDescription\": \"Stopping network for cassandra\" \
  	} \
  }"

  STEP=$((STEP+1))
  curl -XPUT -sS $DASHBOARD_URL -H "Content-Type: application/json" -d "{ \
    \"meta\": { \
      \"progress\": \"$STEP\" \
    } \
  }"

  docker stop -t 5 $DOCKERNETNAME
  docker rm $DOCKERNETNAME

  curl -XPUT -sS $DASHBOARD_URL -H "Content-Type: application/json" -d "{ \
    \"meta\": { \
      \"stateDescription\": \"Stopping service cassandra\", \
      \"progress\": \"$STEP\" \
    } \
  }"
  STEP=$((STEP+1))
  curl -XPUT -sS $DASHBOARD_URL -H "Content-Type: application/json" -d "{ \
    \"meta\": { \
      \"progress\": \"$STEP\" \
    } \
  }"
  docker stop -t 10 $DOCKERSSHDNAME
  docker rm $DOCKERSSHDNAME
  docker stop -t 30 $DOCKERNAME
  docker rm $DOCKERNAME


curl -XDELETE -sS $DASHBOARD_URL

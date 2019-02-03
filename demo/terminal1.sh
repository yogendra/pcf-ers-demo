#!/usr/bin/env bash
SCRIPT_DIR=$(cd `dirname $0`; pwd)

APP_NAME=attendees
DB_NAME=attendees-db
APPV2_NAME=attendees-v2
APPV2_JAR=target/pcf-ers-demo-2.0-SNAPSHOT.jar


COURSE_HOME=$(cd $SCRIPT_DIR/..; pwd)

. $SCRIPT_DIR/demo-magic.sh


PCF_DOMAIN=$(cf domains | grep shared | grep -v "tcp\|internal" | awk {'print $1'})
if [[ ! -f $PCF_DOMAIN.env ]]
then
  echo "No environment file for $PCF_DOMAIN."
  exit 1
fi

. $SCRIPT_DIR/$PCF_DOMAIN.env

function notice {

cat <<EOF
======================================================================
$*
======================================================================
EOF
}

# Clean Build Application
pe "./mvnw clean install"

# Push Application
pe "cf push"

# Show application list
pe "cf app $APP_NAME"


APP_URL=$(cf app $APP_NAME | grep routes | head -1 | awk {'print $2'})
APP_HOSTNAME=$(echo $APP_URL | sed 's/.$PCF_DOMAIN//')
APPV2_HOSTNAME=$(echo $APP_URL | sed 's/.$PCF_DOMAIN/-temp/')
APPV2_URL=$APPV2_HOSTNAME.$PCF_DOMAIN

# Open new browser
pe "open https://$APP_URL"

notice <<EOF
Open 2 new terminals new terminal now and tail the logs
cf logs $APP_NAME | grep \"API\|CELL\"
cf event $APP_NAME
EOF


# See events
pe "cf events $APP_NAME"


# Scale Up
pe "cf scale $APP_NAME -m 1G"
pe "cf app $APP_NAME"

# Scale Down
pe "cf scale $APP_NAME -m 768M"
pe "cf app $APP_NAME"

# Scale Out
pe "cf scale $APP_NAME -i 3"
pe "cf app $APP_NAME"

pe "open https://$APP_URL/basics"

pe "cf app $APP_NAME"

# Create service

pe "cf marketplace"
pe "cf create-service $DB_SERVICE $DB_PLAN $DB_NAME"

echo Waiting to check the service is created succesful

while [[ $(cf services | grep $DB_NAME | awk {'print $5,$6'}) != "create succeeded" ]]
do
  echo -n .
done

pe "cf services"

# Bind services
pe "cf bind-service $APP_NAME $DB_NAME"
pe "cf env $APP_NAME"
pe "cf restage $APP_NAME"



# Blue Green Deployment

pe "cf scale $APP_NAME -i 2"

pe "cf routes"


pe "$COURSE_HOME/buildv2.sh"
notice <<EOF
Lets start bluegreen wizard to demonstrate zero-downtime
EOF

pe "open https://$APP_URL/bluegreen"

pe "cf push $APPV2_NAME -p $APPV2_JAR -m 768M --hostname $APPV2_HOSTNAME --no-start"

pe "cf bind-service $APPV2_NAME $DB_NAME"

pe "cf start $APPV2_NAME"

pe "open https://$APPV2_URL"

pe "cf map-route $APPV2_NAME $PCF_DOMAIN -n $APP_HOSTNAME"

pe "cf scale $APPV2_NAME -i 2"

pe "cf scale $APP_NAME -i 1"

pe "cf app $APP_NAME"

pe "cf app $APPV2_NAME"

pe "cf unmap-route $APPV2_NAME $PCF_DOMAIN -n $APPV2_NAME"

pe "cf delete $APP_NAME"

pe "cf rename $APPV2_NAME $APP_NAME"

pe "cf restart-app-instance $APP_NAME 0"

pe "cf restart-app-instance $APP_NAME 1"

notice <<EOF
Thats it. Done.
EOF

pw "cf scale $APP_NAME -i 1"


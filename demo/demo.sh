#!/usr/bin/env bash
clear 
tsession=pcf-ers-demo
DEMO_PROMPT="${GREEN}➜ ${CYAN}\W$ "
SCRIPT_DIR=$(cd `dirname $0`; pwd)
SCRIPT=$SCRIPT_DIR/$(basename $0)

APP_NAME=attendees
DB_NAME=attendees-db
APPV2_NAME=attendees-v2
APPV2_JAR=target/pcf-ers-demo-2.0-SNAPSHOT.jar


COURSE_HOME=$(cd $SCRIPT_DIR/..; pwd)

. $SCRIPT_DIR/demo-magic.sh

if ! cf target 
then 
  exit 1
fi

PCF_DOMAIN=$(cf domains | grep shared | grep -v "tcp\|internal" |head -1 | awk {'print $1'})
if [[ ! -f "$SCRIPT_DIR/$PCF_DOMAIN.env" ]]
then
  echo "No environment file for $PCF_DOMAIN."
  exit 1
fi

. $SCRIPT_DIR/$PCF_DOMAIN.env

function notice () {
echo ======================================================================
while read -r line; do echo $line; done; 
echo  ======================================================================
}


function demo(){
  # Clean Build Application
  pe "./mvnw clean install"

  # Push Application
  pe "cf push"

  # Show application list
  pe "cf app $APP_NAME"


  APP_URL=$(cf app $APP_NAME | grep routes | head -1 | awk {'print $2'})
  APP_HOSTNAME=$(echo $APP_URL | sed "s/.$PCF_DOMAIN//")
  APPV2_HOSTNAME=${APP_HOSTNAME}-temp
  APPV2_URL=$APPV2_HOSTNAME.$PCF_DOMAIN

  # Open new browser
  pe "open https://$APP_URL"

  tmux \
    split-window "$SCRIPT app-details" \; \
    split-window "$SCRIPT logs" \; \
    select-layout even-vertical \; \
    select-pane -t 0



  # See events
  pe "cf events $APP_NAME"

  # Scale Up
  pe "cf scale $APP_NAME -m 1G -f"

  # Scale Down
  pe "cf scale $APP_NAME -m 768M -f"

  # Scale Out
  pe "cf scale $APP_NAME -i 3 -f"

  pe "open https://$APP_URL/basics"


  # Create service

  pe "cf marketplace"

  tmux \
    kill-pane -t 1 \; \
    kill-pane -t 1
    
  pe "cf create-service $DB_SERVICE $DB_PLAN $DB_NAME"

  echo Waiting to check the service is created succesful

  while [[ -z $(cf services | grep attendees-db | grep 'create succeeded') ]]
  do
    echo -n .
  done

  pe "cf services"

  # Bind services
  pe "cf bind-service $APP_NAME $DB_NAME"
  pe "cf env $APP_NAME"
  pe "cf restage $APP_NAME"

  # Blue Green Deployment
  clear
  pe "cf scale $APP_NAME -i 2 -f"

  pe "cf routes"

  pe "$COURSE_HOME/buildv2.sh"
  notice <<EOF
  Lets start bluegreen wizard to demonstrate zero-downtime
EOF

  pe "open https://$APP_URL/bluegreen"

  pe "cf push $APPV2_NAME -p $APPV2_JAR -m 768M --hostname $APPV2_HOSTNAME --no-start"
  
  APPV2_URL=$(cf app attendees-v2 | grep routes | grep $PCF_DOMAIN | awk {'print $2'} | head -1  )
  APPV2_HOSTNAME=$(echo $APPV2_URL | sed "s/.$PCF_DOMAIN//")

  pe "cf bind-service $APPV2_NAME $DB_NAME"

  pe "cf start $APPV2_NAME"

  pe "open https://$APPV2_URL"

  pe "cf map-route $APPV2_NAME $PCF_DOMAIN -n $APP_HOSTNAME"

  pe "cf scale $APPV2_NAME -i 2 -f"

  pe "cf scale $APP_NAME -i 1 -f"

  pe "cf app $APP_NAME"

  pe "cf app $APPV2_NAME"

  pe "cf unmap-route $APPV2_NAME $PCF_DOMAIN -n $APPV2_HOSTNAME"

  pe "cf delete $APP_NAME"

  pe "cf rename $APPV2_NAME $APP_NAME"

  pe "cf restart-app-instance $APP_NAME 0"

  pe "cf restart-app-instance $APP_NAME 1"

  notice <<EOF
  Thats it. Done.
EOF

  pe "cf scale $APP_NAME -i 1"
  cf delete -f -r attendees
  cf delete-service -f attendees-db

}


function app-details(){
  watch -n 0.5 --color cf app $APP_NAME

}
function logs(){
  cf logs $APP_NAME | grep "CELL\|API"
  wait
}

function driver(){  
  tmux new -s $tsession "$SCRIPT demo" 
}
OPERATION=$1; shift

[[ -z $OPERATION ]] && OPERATION=driver

echo $OPERATION

$OPERATION $@


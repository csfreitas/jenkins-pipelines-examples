

DEV_PROJECT=$1
PROJECT=$2

if [ -z "$DEV_PROJECT" ]
  then
  	echo "DEV_PROJECT o comprimento é zero -  informar parametro $1"
  	echo "Exiting..."
  	exit 0
  elif [ -z "$PROJECT" ];
  then
  	echo "PROJECT o comprimento é zero -  informar parametro $2"
  	echo "Exiting..."
  	exit 0
fi
# Set up Production Project
oc policy add-role-to-group system:image-puller system:serviceaccounts:${PROJECT} -n ${DEV_PROJECT}
oc policy add-role-to-user edit system:serviceaccount:cicd:jenkins -n ${PROJECT}

# Set up Blue Application
oc apply -f openshift-tasks-blue-config.yaml -n ${PROJECT}
oc apply -f openshift-tasks-dc-blue.yaml -n ${PROJECT}
oc apply -f openshift-tasks-svc-blue.yaml -n ${PROJECT}

# Set up Green Application
oc apply -f openshift-tasks-green-config.yaml -n ${PROJECT}
oc apply -f openshift-tasks-dc-green.yaml -n ${PROJECT}
oc apply -f openshift-tasks-svc-green.yaml -n ${PROJECT}

# Expose Green service as route -> Force Green -> Blue deployment on first run
oc apply -f openshift-tasks-route-prod.yaml -n ${PROJECT}

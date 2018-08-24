#!/bin/bash

UP_DOWN="$1"
CHANNEL_NAME="$2"
IF_COUCHDB="$4"
IF_CA_MODE="$3"

: ${IF_CA_MODE:=" "}
: ${CLI_TIMEOUT:="10000"}

COMPOSE_FILE=docker-compose-cli.yaml
COMPOSE_FILE_COUCH=docker-compose-couch.yaml

function printHelp () {
	echo "Usage: ./network_setup <up|down|restart> <channel> <ca> <couchdb>.\nThe arguments must be in order."
}

function validateArgs () {
    log yellow "############################ validate args ########################### "
	
    if [ $# -lt 1 ]; then
        log red "Empty args options, Option up / down / restart not mentioned"
        printHelp
        exit 1
    fi     

    if [ -z "${UP_DOWN}" ]; then
        log red "Option up / down / restart not mentioned"
        printHelp
        exit 1
    fi
	
	if [ -z "${CHANNEL_NAME}" ]; then
		log yellow "setting to default channel 'mychannel'"
		CHANNEL_NAME=mychannel
	fi
	
	if [ "$IF_CA_MODE" == "ca" ]; then
		COMPOSE_FILE=docker-compose-e2e-${FABRIC_NETWORK_CONFIGTX_VERSION}.yaml
		log yellow "setting to COMPOSE_FILE [${COMPOSE_FILE}]"
	fi
	echo
}

function clearContainers () {
	log yellow "########################## clean container ########################### "
    
	CONTAINER_IDS=$(docker ps -aq)
    if [ -z "$CONTAINER_IDS" -o "$CONTAINER_IDS" = " " ]; then
        log sky_blue "---- No containers available for deletion ----"
    else
        log purple "==> remove docker containers: ${CONTAINER_IDS}"
        docker rm -f $CONTAINER_IDS
    fi
    echo
}

function removeUnwantedImages() {
	log yellow "######################## clean unwanted images ####################### "

    DOCKER_IMAGE_IDS=$(docker images | grep "dev\|none\|test-vp\|peer[0-9]-" | awk '{print $3}')
    if [ -z "$DOCKER_IMAGE_IDS" -o "$DOCKER_IMAGE_IDS" = " " ]; then
        log sky_blue "---- No images available for deletion ----"
    else
        log purple "==> remove docker images: $DOCKER_IMAGE_IDS"
        docker rmi -f $DOCKER_IMAGE_IDS
    fi
    echo
}

function cleanDataStore(){
	log yellow "########################### clean data store ######################### "
	
    log purple "clean hyperledger store data"
    rm -rfv /var/hyperledger/* /etc/hyperledger/*

    mkdir -pv /var/fabric/config
    log purple "clean hyperledger fabric key value store"
    rm -fv /var/fabric/config/fabric-kv-store.properties
	echo
}

# disabled
function cleanNetwork() {
	log yellow "############################ clean network ########################### "
    
	lines=`docker ps -a | grep 'dev-peer' | wc -l`

    if [ "$lines" -gt 0 ]; then
    docker ps -a | grep 'dev-peer' | awk '{print $1}' | xargs docker rm -f
    fi

    lines=`docker images | grep 'dev-peer' | grep 'dev-peer' | wc -l`
    if [ "$lines" -gt 0 ]; then
    docker images | grep 'dev-peer' | awk '{print $1}' | xargs docker rmi -f
    fi

    lines=`docker ps -aq | wc -l`
    if ((lines > 0)); then
    docker stop $(docker ps -aq)
    docker rm $(docker ps -aq)
    fi

    lines=`docker network ls -f 'name=basic_default' | wc -l`
    if ((lines > 1)); then
      docker network rm basic_default
    fi
	
	echo
}

function networkUp () {
	log yellow "######################## start fabric network ######################## "
	
    if [ ! -d "./e2e-network/${FABRIC_NETWORK_CONFIGTX_VERSION}/crypto-config" ]; then
      log red "e2e-network/${FABRIC_NETWORK_CONFIGTX_VERSION}/crypto-config directory not exists."
      #source ./e2e-network/generate.sh -v ${FABRIC_NETWORK_CONFIGTX_VERSION} -c ${CHANNEL_NAME} clean gen merge
	  log _blue "\nPlease generate the required [crypto-config] files\nExample:"
	  log _blue "\t cd e2e-network \n\t sudo sh generate.sh -v ${FABRIC_NETWORK_CONFIGTX_VERSION} -c ${CHANNEL_NAME} clean gen merge"
	  exit 1
    fi

    if [ ! -f "./e2e-network/${FABRIC_NETWORK_CONFIGTX_VERSION}/channel-artifacts/${CHANNEL_NAME}.tx" ]; then
      log red "e2e-network/${FABRIC_NETWORK_CONFIGTX_VERSION}/channel-artifacts/${CHANNEL_NAME}.tx file not exists."
      #source ./e2e-network/generate.sh -v ${FABRIC_NETWORK_CONFIGTX_VERSION} -c ${CHANNEL_NAME} gen-channel 
	  log _blue "\nPlease generate the required [${CHANNEL_NAME}.tx] files\nExample:"
	  log _blue "\t cd e2e-network \n\t sudo sh generate.sh -v ${FABRIC_NETWORK_CONFIGTX_VERSION} -c ${CHANNEL_NAME} gen-channel"
      exit 1
    fi

    if [ "${IF_COUCHDB}" == "couchdb" ]; then
      log purple "==> docker-compose -f $COMPOSE_FILE -f $COMPOSE_FILE_COUCH up -d "
      ADMIN_USER=admin ADMIN_PASSWORD=admin docker-compose -f $COMPOSE_FILE -f $COMPOSE_FILE_COUCH -f docker-compose-prom.yaml up # -d 2>&1
    else
      log purple "==> docker-compose -f $COMPOSE_FILE up -d "
      ADMIN_USER=admin ADMIN_PASSWORD=admin docker-compose -f $COMPOSE_FILE -f docker-compose-prom.yaml up  #-d 2>&1
    fi

    #if [ $? -ne 0 ]; then
        #log red "ERROR !!!! Unable to pull the images "
        #exit 1
    #fi

    #echo "==> docker logs -f cli"
    #echo
    #docker logs -f cli
	echo
}

function networkDown () {
    log yellow "#################### stop & remove fabric network #################### "
	
    if [ "${IF_COUCHDB}" == "couchdb" ]; then
      log purple "==> docker-compose -f $COMPOSE_FILE -f $COMPOSE_FILE_COUCH down"
      docker-compose -f $COMPOSE_FILE -f $COMPOSE_FILE_COUCH -f docker-compose-prom.yaml down
    else
      log purple "==> docker-compose -f $COMPOSE_FILE down"
      docker-compose -f $COMPOSE_FILE -f docker-compose-prom.yaml down
    fi
	echo
	
    #Cleanup the chaincode containers
    clearContainers

    #Cleanup images
    removeUnwantedImages
    
    #Cleanup data store
    cleanDataStore    
	echo
}


# import
#--------------------------------------------------------------------------
source ./scripts/log.sh
source .env


# check args
#--------------------------------------------------------------------------
validateArgs $@


# varibles
#--------------------------------------------------------------------------
log red "COMPOSE_FILE=${COMPOSE_FILE}"
log red "IF_COUCHDB=${IF_COUCHDB}"
log red "IF_CA_MODE=${IF_CA_MODE}"
log red "CHANNEL_NAME=${CHANNEL_NAME}"
log red "TIMEOUT=${CLI_TIMEOUT}"
log red "FABRIC_NETWORK_CONFIGTX_VERSION=${FABRIC_NETWORK_CONFIGTX_VERSION}"
echo

export CHANNEL_NAME=${CHANNEL_NAME}
export TIMEOUT=${CLI_TIMEOUT}


#Create the network using docker compose
#--------------------------------------------------------------------------
if [ "${UP_DOWN}" == "up" ]; then
	networkUp
elif [ "${UP_DOWN}" == "down" ]; then ## Clear the network
	networkDown
elif [ "${UP_DOWN}" == "restart" ]; then ## Restart the network
	networkDown
	networkUp
elif [ "${UP_DOWN}" == "clean" ]; then ## clean all
	networkDown
	cleanNetwork
else
	printHelp
	exit 1
fi

#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#


UP_DOWN="$1"
IF_COUCHDB="$2"

: ${CLI_TIMEOUT:="10000"}

COMPOSE_FILE=docker-compose-cli.yaml
COMPOSE_FILE_COUCH=docker-compose-couch.yaml
#COMPOSE_FILE=docker-compose-e2e.yaml

function printHelp () {
	echo "Usage: ./network_setup <up|down> <couchdb>.\nThe arguments must be in order."
}

function validateArgs () {	
    printf "\n\n"
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
}

function clearContainers () {
    CONTAINER_IDS=$(docker ps -aq)
    if [ -z "$CONTAINER_IDS" -o "$CONTAINER_IDS" = " " ]; then
        log sky_blue " ---- No containers available for deletion ----"
    else
        log purple "==> remove docker containers: ${CONTAINER_IDS}"
        docker rm -f $CONTAINER_IDS
    fi
    echo
}

function removeUnwantedImages() {
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

    log purple "clean hyperledger couchdb data"
    rm -rfv /var/hyperledger/*

    mkdir -pv /var/fabric/config
    log purple "clean hyperledger fabric data store"
    rm -fv /var/fabric/config/fabric-kv-store.properties
}

function cleanNetwork() {
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
}

function networkUp () {
    if [ -d "./e2e-network/${FABRIC_NETWORK_CONFIGTX_VERSION}/crypto-config" ]; then
      log red "e2e-network/${FABRIC_NETWORK_CONFIGTX_VERSION}/crypto-config directory already exists."         
    fi

    echo
    if [ "${IF_COUCHDB}" == "couchdb" ]; then
      log purple "==> docker-compose -f $COMPOSE_FILE -f $COMPOSE_FILE_COUCH up -d "2>&1
      docker-compose --force-recreate -f $COMPOSE_FILE -f $COMPOSE_FILE_COUCH up -d 2>&1
    else
      log purple "==> CHANNEL_NAME=$CH_NAME TIMEOUT=$CLI_TIMEOUT docker-compose -f $COMPOSE_FILE up -d "2>&1
      docker-compose --force-recreate -f $COMPOSE_FILE up -d 2>&1
    fi

    if [ $? -ne 0 ]; then
        log red "ERROR !!!! Unable to pull the images "
        exit 1
    fi

    #echo "==> docker logs -f cli"
    #echo
    #docker logs -f cli
}

function networkDown () {
    echo
    log purple "==> docker-compose -f $COMPOSE_FILE down"
    docker-compose -f $COMPOSE_FILE down

    #Cleanup the chaincode containers
    echo
    log purple "==> Cleanup the chaincode containers"
    clearContainers

    #Cleanup images
    echo
    log purple "==> Cleanup images"
    removeUnwantedImages
    
    echo
    cleanDataStore    
}


source ./scripts/log.sh
source .env

validateArgs


#Create the network using docker compose
if [ "${UP_DOWN}" == "up" ]; then
	networkUp
elif [ "${UP_DOWN}" == "down" ]; then ## Clear the network
	networkDown
elif [ "${UP_DOWN}" == "restart" ]; then ## Restart the network
	networkDown
	networkUp
else
	printHelp
	exit 1
fi

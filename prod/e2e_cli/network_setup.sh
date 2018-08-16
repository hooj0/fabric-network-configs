#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#


UP_DOWN="$1"
CH_NAME="$2"
CLI_TIMEOUT="$3"
IF_COUCHDB="$4"

: ${CLI_TIMEOUT:="10000"}

COMPOSE_FILE=docker-compose-cli.yaml
COMPOSE_FILE_COUCH=docker-compose-couch.yaml
#COMPOSE_FILE=docker-compose-e2e.yaml

function printHelp () {
	echo "Usage: ./network_setup <up|down> <\$channel-name> <\$cli_timeout> <couchdb>.\nThe arguments must be in order."
}

function validateArgs () {
	if [ -z "${UP_DOWN}" ]; then
		echo "Option up / down / restart not mentioned"
		printHelp
		exit 1
	fi
	if [ -z "${CH_NAME}" ]; then
		echo "setting to default channel 'mychannel'"
		CH_NAME=mychannel
	fi
}

function clearContainers () {
    CONTAINER_IDS=$(docker ps -aq)
    if [ -z "$CONTAINER_IDS" -o "$CONTAINER_IDS" = " " ]; then
        echo "---- No containers available for deletion ----"
    else
        echo "==> remove docker containers: "$CONTAINER_IDS
        docker rm -f $CONTAINER_IDS
    fi
    echo
}

function removeUnwantedImages() {
    DOCKER_IMAGE_IDS=$(docker images | grep "dev\|none\|test-vp\|peer[0-9]-" | awk '{print $3}')
    if [ -z "$DOCKER_IMAGE_IDS" -o "$DOCKER_IMAGE_IDS" = " " ]; then
        echo "---- No images available for deletion ----"
    else
        echo "==> remove docker images: "$DOCKER_IMAGE_IDS
        docker rmi -f $DOCKER_IMAGE_IDS
    fi
    echo
}

function networkUp () {
    if [ -d "./crypto-config" ]; then
      echo "crypto-config directory already exists."
    else
      #Generate all the artifacts that includes org certs, orderer genesis block,
      # channel configuration transaction
      echo
      echo "==> source generateArtifacts.sh $CH_NAME"
      source generateArtifacts.sh $CH_NAME
    fi

    echo
    if [ "${IF_COUCHDB}" == "couchdb" ]; then
      echo "==> CHANNEL_NAME=$CH_NAME TIMEOUT=$CLI_TIMEOUT docker-compose -f $COMPOSE_FILE -f $COMPOSE_FILE_COUCH up -d "2>&1
      CHANNEL_NAME=$CH_NAME TIMEOUT=$CLI_TIMEOUT docker-compose -f $COMPOSE_FILE -f $COMPOSE_FILE_COUCH up -d 2>&1
    else
      echo "==> CHANNEL_NAME=$CH_NAME TIMEOUT=$CLI_TIMEOUT docker-compose -f $COMPOSE_FILE up -d "2>&1
      CHANNEL_NAME=$CH_NAME TIMEOUT=$CLI_TIMEOUT docker-compose -f $COMPOSE_FILE up -d 2>&1
    fi

    if [ $? -ne 0 ]; then
        echo "ERROR !!!! Unable to pull the images "
        exit 1
    fi

    echo "==> docker logs -f cli"
    echo
    docker logs -f cli
}

function networkDown () {
    echo
    echo "==> docker-compose -f $COMPOSE_FILE down"
    docker-compose -f $COMPOSE_FILE down

    #Cleanup the chaincode containers
    echo
    echo "==> Cleanup the chaincode containers"
    clearContainers

    #Cleanup images
    echo
    echo "==> Cleanup images"
    removeUnwantedImages

    # remove orderer block and other channel configuration transactions and certs
    echo
    echo "==> rm -rf channel-artifacts/*.block channel-artifacts/*.tx crypto-config"
    rm -rf channel-artifacts/*.block channel-artifacts/*.tx crypto-config
    echo
}

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

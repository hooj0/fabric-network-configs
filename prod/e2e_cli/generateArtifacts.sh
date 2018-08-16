#!/bin/bash +x
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#


#set -e

CHANNEL_NAME=$1
CHANNEL_ARTIFACTS_ROOT=$2

: ${CHANNEL_NAME:="mychannel"}
: ${CHANNEL_ARTIFACTS_ROOT:="channel-artifacts"}

echo "CHANNEL_NAME: $CHANNEL_NAME"
echo "CHANNEL_ARTIFACTS_ROOT: $CHANNEL_ARTIFACTS_ROOT"

export FABRIC_ROOT=$PWD/../..
export FABRIC_CFG_PATH=$PWD
echo

OS_ARCH=$(echo "$(uname -s|tr '[:upper:]' '[:lower:]'|sed 's/mingw64_nt.*/windows/')-$(uname -m | sed 's/x86_64/amd64/g')" | awk '{print tolower($0)}')

## Using docker-compose template replace private key file names with constants
function replacePrivateKey () {
	ARCH=`uname -s | grep Darwin`
	if [ "$ARCH" == "Darwin" ]; then
		OPTS="-it"
	else
		OPTS="-i"
	fi

    echo
    echo "==> cp docker-compose-e2e-template.yaml docker-compose-e2e.yaml"
	cp docker-compose-e2e-template.yaml docker-compose-e2e.yaml

    CURRENT_DIR=$PWD
    cd crypto-config/peerOrganizations/org1.example.com/ca/
    PRIV_KEY=$(ls *_sk)
    cd $CURRENT_DIR

    sed $OPTS "s/CA1_PRIVATE_KEY/${PRIV_KEY}/g" docker-compose-e2e.yaml

    cd crypto-config/peerOrganizations/org2.example.com/ca/
    PRIV_KEY=$(ls *_sk)
    cd $CURRENT_DIR

    sed $OPTS "s/CA2_PRIVATE_KEY/${PRIV_KEY}/g" docker-compose-e2e.yaml
    echo
}

## Generates Org certs using cryptogen tool
function generateCerts (){
	CRYPTOGEN=$FABRIC_ROOT/release/$OS_ARCH/bin/cryptogen

	if [ -f "$CRYPTOGEN" ]; then
        echo "Using cryptogen -> $CRYPTOGEN"
	else
	    echo "Building cryptogen"
	    echo "===> make -C $FABRIC_ROOT release"
	    make -C $FABRIC_ROOT release
	fi

	echo
	echo "##########################################################"
	echo "##### Generate certificates using cryptogen tool #########"
	echo "##########################################################"

	echo "==> cryptogen generate --config=./crypto-config.yaml"
	$CRYPTOGEN generate --config=./crypto-config.yaml
	echo
}

## Generate orderer genesis block , channel configuration transaction and anchor peer update transactions
function generateChannelArtifacts() {

	CONFIGTXGEN=$FABRIC_ROOT/release/$OS_ARCH/bin/configtxgen
	if [ -f "$CONFIGTXGEN" ]; then
        echo "Using configtxgen -> $CONFIGTXGEN"
	else
	    echo "Building configtxgen"
	    echo "===> make -C $FABRIC_ROOT release"
	    make -C $FABRIC_ROOT release
	fi

    echo
	echo "##########################################################"
	echo "#########  Generating Orderer Genesis block ##############"
	echo "##########################################################"
	# Note: For some unknown reason (at least for now) the block file can't be
	# named orderer.genesis.block or the orderer will fail to launch!
	echo "==> cryptogen -profile TwoOrgsOrdererGenesis -outputBlock ./$CHANNEL_ARTIFACTS_ROOT/genesis.block"
	$CONFIGTXGEN -profile TwoOrgsOrdererGenesis -outputBlock ./$CHANNEL_ARTIFACTS_ROOT/genesis.block

	echo
	echo "#################################################################"
	echo "### Generating channel configuration transaction 'channel.tx' ###"
	echo "#################################################################"
	echo "==> cryptogen -profile TwoOrgsChannel -outputCreateChannelTx ./$CHANNEL_ARTIFACTS_ROOT/channel.tx -channelID $CHANNEL_NAME"
	$CONFIGTXGEN -profile TwoOrgsChannel -outputCreateChannelTx ./$CHANNEL_ARTIFACTS_ROOT/channel.tx -channelID $CHANNEL_NAME

	echo
	echo "#################################################################"
	echo "#######    Generating anchor peer update for Org1MSP   ##########"
	echo "#################################################################"
	echo "==> cryptogen -profile TwoOrgsChannel -outputAnchorPeersUpdate ./$CHANNEL_ARTIFACTS_ROOT/Org1MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org1MSP"
	$CONFIGTXGEN -profile TwoOrgsChannel -outputAnchorPeersUpdate ./$CHANNEL_ARTIFACTS_ROOT/Org1MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org1MSP

	echo
	echo "#################################################################"
	echo "#######    Generating anchor peer update for Org2MSP   ##########"
	echo "#################################################################"
	echo "==> cryptogen -profile TwoOrgsChannel -outputAnchorPeersUpdate ./$CHANNEL_ARTIFACTS_ROOT/Org2MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org2MSP"
	$CONFIGTXGEN -profile TwoOrgsChannel -outputAnchorPeersUpdate ./$CHANNEL_ARTIFACTS_ROOT/Org2MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org2MSP
	echo
}

function cleanChannelArtifacts() {

    echo
	echo "#################################################################"
	echo "#######            clean channel artifacts             ##########"
	echo "#################################################################"

    echo "==> rm -rf $CHANNEL_ARTIFACTS_ROOT/*.block $CHANNEL_ARTIFACTS_ROOT/*.tx crypto-config"
    rm -rf $CHANNEL_ARTIFACTS_ROOT/*.block $CHANNEL_ARTIFACTS_ROOT/*.tx crypto-config
    mkdir $CHANNEL_ARTIFACTS_ROOT && crypto-config
    echo
}

cleanChannelArtifacts
generateCerts
replacePrivateKey
generateChannelArtifacts


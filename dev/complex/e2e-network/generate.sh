#!/bin/bash +x

#set -e
#set -uo pipefail
trap "echo 'error: Script failed: see failed command above'" ERR


# import files
# -------------------------------------------------------------------------------
source ../scripts/log.sh $@


# common variables
# -------------------------------------------------------------------------------
FABRIC_ROOT="/opt/gopath/src/github.com/hyperledger/fabric"
export FABRIC_ROOT=$FABRIC_ROOT
export FABRIC_CFG_PATH=$PWD

log green "FABRIC_ROOT: ${FABRIC_ROOT}"
log green "FABRIC_CFG_PATH: ${FABRIC_CFG_PATH}"
echo

OS_ARCH=$(echo "$(uname -s|tr '[:upper:]' '[:lower:]'|sed 's/mingw64_nt.*/windows/')-$(uname -m | sed 's/x86_64/amd64/g')" | awk '{print tolower($0)}')

function usageHelp() {
cat << HELP
USAGE: $0 [OPTIONS] COMMANDS

OPTIONS: 
 -h help 		use the help manual.
 -v version 		fabric configtx generate config version.

COMMANDS:
	clean 			clean store & config
	gen 			generate channel & artifacts & certificates
	gen-channel 		generate channel configtx
	merge 			merge channel & artifacts & certificates to version directory
	regenerate 		regenerate channel & artifacts & certificates
	
EXAMPLE: 
	$0 -h
	$0 help

	$0 -v v1.1 -c mycc gen
	$0 -v v1.1 -c mycc regenerate
	$0 -c mychannel -c articlechannel -c mycc gen-channel
	
	$0 merge
	$0 clean


HELP
exit 0
}

## Using docker-compose template replace private key file names with constants
function replacePrivateKey () {
	echo
	echo "##########################################################"
	echo "#####         replace certificates  key          #########"
	echo "##########################################################"
	
	ARCH=`uname -s | grep Darwin`
	echo "ARCH: $ARCH"
	if [ "$ARCH" == "Darwin" ]; then
		OPTS="-it"
	else
		OPTS="-i"
	fi
	echo "OPTS: $OPTS"

    echo
    log yellow "==> cp -r scripts/compose-script-template.sh scripts/$VERSION_DIR/compose-script.sh"
    mkdir -pv scripts/$VERSION_DIR/
	cp -rv scripts/compose-script-template.sh scripts/$VERSION_DIR/compose-script.sh

    CURRENT_DIR=$PWD
    cd ./$CRYPTO_CONFIG_LOCATION/peerOrganizations/org1.foo.com/ca/
    PRIV_KEY=$(ls *_sk)
    cd $CURRENT_DIR
	
    sed $OPTS "s/CA1_PRIVATE_KEY/${PRIV_KEY}/g" scripts/$VERSION_DIR/compose-script.sh 

    cd ./$CRYPTO_CONFIG_LOCATION/peerOrganizations/org2.bar.com/ca/
    PRIV_KEY=$(ls *_sk)
    cd $CURRENT_DIR

    sed $OPTS "s/CA2_PRIVATE_KEY/${PRIV_KEY}/g" scripts/$VERSION_DIR/compose-script.sh 
    echo
}

## Generates Org certs using cryptogen tool
function generateCerts() {
	CRYPTOGEN=$FABRIC_ROOT/release/$OS_ARCH/bin/cryptogen

	if [ -f "$CRYPTOGEN" ]; then
        log yellow "Using cryptogen -> $CRYPTOGEN"
	else
	    log yellow "Building cryptogen"
	    log yellow "===> make -C $FABRIC_ROOT release"
	    make -C $FABRIC_ROOT release
	fi

	echo
	echo "##########################################################"
	echo "##### Generate certificates using cryptogen tool #########"
	echo "##########################################################"

	log yellow "==> cryptogen generate --config=./$CRYPTO_CONFIG_FILE --output=./$CRYPTO_CONFIG_LOCATION"
	$CRYPTOGEN generate --config=./$CRYPTO_CONFIG_FILE --output=./$CRYPTO_CONFIG_LOCATION
	echo
}

## Generate orderer genesis block , channel configuration transaction and anchor peer update transactions
function checkConfigtxgen() {
	CONFIGTXGEN=$FABRIC_ROOT/release/$OS_ARCH/bin/configtxgen
	
	if [ -f "$CONFIGTXGEN" ]; then
        log yellow "Using configtxgen -> $CONFIGTXGEN"
	else
	    log yellow "Building configtxgen"
	    log yellow "===> make -C $FABRIC_ROOT release"
	    make -C $FABRIC_ROOT release
	fi
}

function generateGenesisBlock() {
	echo
	echo "##########################################################"
	echo "#########  Generating Orderer Genesis block ##############"
	echo "##########################################################"
	# Note: For some unknown reason (at least for now) the block file can't be
	# named orderer.genesis.block or the orderer will fail to launch!
	log yellow "==> cryptogen -profile TwoOrgsOrdererGenesis${version} -outputBlock ./$CHANNEL_ARTIFACTS_LOCATION/genesis.block"
	$CONFIGTXGEN -profile TwoOrgsOrdererGenesis${version} -outputBlock ./$CHANNEL_ARTIFACTS_LOCATION/genesis.block
}

function generateChannelArtifacts() {

	echo
	echo "#################################################################"
	echo "### Generating channel configuration transaction 'channel.tx' ###"
	echo "#################################################################"
	
	for channel in "$@"; do
		log yellow "==> cryptogen -profile TwoOrgsChannel${version} -outputCreateChannelTx ./$CHANNEL_ARTIFACTS_LOCATION/$channel.tx -channelID $channel"
		$CONFIGTXGEN -profile TwoOrgsChannel${version} -outputCreateChannelTx ./$CHANNEL_ARTIFACTS_LOCATION/$channel.tx -channelID $channel

		if [ generateAnchorPeer == "true" ]; then
			generateAnchorPeerArtifacts $channel
		fi
	done	
}

function generateAnchorPeerArtifacts() {
	echo
	echo "#################################################################"
	echo "#######    Generating anchor peer update for Org1MSP   ##########"
	echo "#################################################################"
	log yellow "==> cryptogen -profile TwoOrgsChannel -outputAnchorPeersUpdate ./$CHANNEL_ARTIFACTS_LOCATION/Org1MSPanchors.tx -channelID $1 -asOrg Org1MSP"
	$CONFIGTXGEN -profile TwoOrgsChannel -outputAnchorPeersUpdate ./$CHANNEL_ARTIFACTS_LOCATION/Org1MSPanchors.tx -channelID $1 -asOrg Org1MSP

	echo
	echo "#################################################################"
	echo "#######    Generating anchor peer update for Org2MSP   ##########"
	echo "#################################################################"
	log yellow "==> cryptogen -profile TwoOrgsChannel -outputAnchorPeersUpdate ./$CHANNEL_ARTIFACTS_LOCATION/Org2MSPanchors.tx -channelID $1 -asOrg Org2MSP"
	$CONFIGTXGEN -profile TwoOrgsChannel -outputAnchorPeersUpdate ./$CHANNEL_ARTIFACTS_LOCATION/Org2MSPanchors.tx -channelID $1 -asOrg Org2MSP
	echo
}

function cleanChannelArtifacts() {

    echo
	echo "#################################################################"
	echo "#######            clean channel artifacts             ##########"
	echo "#################################################################"

	
	log yellow "==> rm -rf ./$VERSION_DIR/"
    [ -n $VERSION_DIR ] && [ -d "./$VERSION_DIR" ] && rm -rfv ./$VERSION_DIR/*

	log yellow "==> rm -rf ./channel-artifacts/* ./crypto-config/* ./scripts/$VERSION_DIR/*"
    rm -rfv ./channel-artifacts/* ./crypto-config/* ./scripts/$VERSION_DIR/*
    
    echo
}

function createChannelArtifactsDir() {

    echo
	echo "#################################################################"
	echo "#######       create channel artifacts directory       ##########"
	echo "#################################################################"

    log yellow "==> mkdir ./channel-artifacts"
	[ ! -d "./channel-artifacts" ] && mkdir -pv ./channel-artifacts 

    log yellow "==> mkdir ./crypto-config"
	[ ! -d "./crypto-config" ] && mkdir -pv ./crypto-config 
    
    echo
}

function mergeArtifactsCryptoDir() {
	echo
	echo "#################################################################"
	echo "#######            merge channel artifacts  files      ##########"
	echo "#################################################################"

	echo "==> mv ./channel-artifacts ./$VERSION_DIR/"
    mv -v ./channel-artifacts ./$VERSION_DIR/

	echo "==> mv ./crypto-config ./$VERSION_DIR/"
    mv -v ./crypto-config ./$VERSION_DIR/

    echo
}


# usage options
# -------------------------------------------------------------------------------
printf "\n\n"
log green "参数列表：$*"

while getopts ":cv:hu" opt; do

	printf "选项：%s ->" $opt
    case $opt in
    	c ) 
			CHANNEL_NAME="$OPTARG,"
		;;
		v ) 
			version="$OPTARG"
			VERSION_DIR=echo "$OPTARG" | tr '.' ''
		;;
		u ) 
			generateAnchorPeer=true
		;;
		h ) 
			usageHelp
		;;        
        ? ) echo "error" exit 1;;
    esac
done

shift $(($OPTIND - 1))
echo "清理后参数列表：$*"


# variable
# ------------------------------------------------------------------------------
: ${CHANNEL_ARTIFACTS_LOCATION:="channel-artifacts"}
: ${CRYPTO_CONFIG_LOCATION:="crypto-config"}
: ${CRYPTO_CONFIG_FILE:="crypto-config.yaml"}
: ${version:="v1.1"}
: ${VERSION_DIR:="_v11"}

log green "CHANNEL_NAME: $CHANNEL_NAME"
log green "CHANNEL_ARTIFACTS_LOCATION: $CHANNEL_ARTIFACTS_LOCATION"
log green "CRYPTO_CONFIG_LOCATION: $CRYPTO_CONFIG_LOCATION"
log green "CRYPTO_CONFIG_FILE: $CRYPTO_CONFIG_FILE"
log green "version: $version"
log green "VERSION_DIR: $VERSION_DIR"


# process
# ------------------------------------------------------------------------------
for opt in "$*"; do
	case "$opt" in
        clean)
            cleanChannelArtifacts
        ;;
        gen)
			checkConfigtxgen
            createChannelArtifactsDir
            generateCerts
			replacePrivateKey
			generateGenesisBlock

			generateChannelArtifacts $CHANNEL_NAME
			#generateAnchorPeerArtifacts
        ;;
        gen-channel)
            generateChannelArtifacts $CHANNEL_NAME
        ;;
        merge)
            mergeArtifactsCryptoDir
        ;;        
        regenerate)            
            clean
            gen
        ;;
        *)
            usageHelp
            exit 1
        ;;
    esac        
done	
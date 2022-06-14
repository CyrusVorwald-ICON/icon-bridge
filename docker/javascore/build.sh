#!/bin/sh

BASE_DIR=$(dirname $0)
. ${BASE_DIR}/../version.sh

DIST_DIR=build/contracts/javascore

build_image() {
    echo $BASE_DIR

    mkdir -p ${DIST_DIR}

    docker build -f ./docker/javascore/Dockerfile . --tag btp/javascore:latest
    docker create -ti --name javascore-dist -i btp/javascore

    docker cp javascore-dist:/dist/bmc-optimized.jar ${DIST_DIR}
    docker cp javascore-dist:/dist/bsh-optimized.jar ${DIST_DIR}
    docker cp javascore-dist:/dist/irc2-token-optimized.jar ${DIST_DIR}
    docker cp javascore-dist:/dist/irc2Tradeable-optimized.jar ${DIST_DIR}
    docker cp javascore-dist:/dist/nativecoin-optimized.jar ${DIST_DIR}
    docker cp javascore-dist:/dist/restrictions-optimized.jar ${DIST_DIR}

    docker rm -f javascore-dist
}

build_image "$@"

#!/bin/bash

air-log INFO "AIR_LOG: '${AIR_LOG}'. Options: [INSPECT, DEBUG]"

arg_config() {
    __INSPECT=false
    __DEBUG=false

    case "${AIR_LOG}" in
        inspect|INSPECT)
            __INSPECT=true
            __DEBUG=true
            ;;
        debug|DEBUG)
            __DEBUG=true
            ;;
    esac
    
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --inspect)              __INSPECT=true ;;
            --debug)                __DEBUG=true ;;
            *) air-log ERROR "Unknown parameter: $1"; exit 64 ;;
        esac
        shift
    done

    if [ "$__INSPECT" = true ]; then
        . setx INSPECT
    fi

    if [ "$__DEBUG" = true ]; then
        source air-log level DEBUG
    fi
}

release_docker() {
    air-log DEBUG AMS=$AMS
    air-log DEBUG AMS_NAME=$AMS_NAME
    air-log DEBUG AMS_REVISION=$AMS_REVISION
    air-log DEBUG AMS_BUILD=$AMS_BUILD
    air-log DEBUG CI_REGISTRY_USER=$CI_REGISTRY_USER
    air-log DEBUG CI_REGISTRY_PASSWORD=$CI_REGISTRY_PASSWORD
    air-log DEBUG CI_REGISTRY=$CI_REGISTRY
    air-log DEBUG CI_REGISTRY_IMAGE=$CI_REGISTRY_IMAGE

    export AMS_IMAGE_REGISTRY=${CI_REGISTRY_IMAGE}/${AMS_NAME}:${AMS_REVISION}
    air-log DEBUG AMS_IMAGE_REGISTRY=${AMS_IMAGE_REGISTRY}

    echo "${CI_REGISTRY_PASSWORD}" | docker login -u "${CI_REGISTRY_USER}" --password-stdin ${CI_REGISTRY} 2>&1 \
        | grep -v -e 'Your password will be stored unencrypted' \
                  -e 'Configure a credential helper to remove this warning'
    
    docker info > docker-info.yml
    ansi-cat docker-info.yml

    air-assert FILE ./.docker/Dockerfile.${AMS_NAME}

    air-copy FILE ./.docker/Dockerfile.${AMS_NAME} ./Dockerfile

    ansi-cat Dockerfile

    

    docker buildx create --use

    docker buildx build -f Dockerfile \
    --build-arg "AMS=${AMS}" \
    --build-arg "AMS_NAME=${AMS_NAME}" \
    --build-arg "AMS_REVISION=${AMS_REVISION}" \
    --build-arg "AMS_BUILD=${AMS_BUILD}" \
    --platform linux/amd64 \
    --no-cache \
    -t ${AMS_IMAGE_REGISTRY} \
    --load \
    .

    docker push ${AMS_IMAGE_REGISTRY}

    export AMS_IMAGE_LAYERS=$(docker inspect ${AMS_IMAGE_REGISTRY} | jq '.[].RootFS.Layers | length')
    export AMS_IMAGE_SIZE=$(docker inspect --format='{{.Size}}' ${AMS_IMAGE_REGISTRY} | awk '{print $1/1024/1024 " MB"}')
}

AMS_NAME=${CI_JOB_NAME##*:}

ams-ctx AHS_ORIGIN
ams-ctx AMS_ORIGIN

arg_config "$@"
source air-layer
release_docker

ams-ctx AMS_IMAGE

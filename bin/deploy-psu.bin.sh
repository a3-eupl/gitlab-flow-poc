#!/bin/bash

set -e

air-log INFO "AIR_LOG: '${AIR_LOG}'. Options: [INSPECT, DEBUG]"

arg_config() {
    __INSPECT=false
    __DEBUG=false
    __NOPING=false

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
            --inspect) __INSPECT=true ;;
            --debug) __DEBUG=true ;;
            --noping) __NOPING=true ;;
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

setup_env() {
    air-log INFO "${ENV_HOME}/${CI_ENVIRONMENT_NAME}.env"
    if [ "$__DEBUG" = true ]; then
        ansi-cat "${ENV_HOME}/${CI_ENVIRONMENT_NAME}.env"
    fi
    set -o allexport
    source "${ENV_HOME}/${CI_ENVIRONMENT_NAME}.env"

    export AMS_DEPLOY=$(date '+%y%m%d-%H%M%S')
    export AMS_ENV=${CI_ENVIRONMENT_NAME}
    export AMS_AREA=${AMS_AREA:-$AMS_ENV}
    if [[ -n "$AMS_AREA" ]]; then
        export AMS_AREA="-${AMS_AREA}"
    fi
    export AMS_HOST="${AMS_NAME}${AMS_AREA}.${AMS_DOMAIN}"
    if [ -z "$AMS_ENDPOINT" ]; then
        export AMS_ENDPOINT="https://${AMS_HOST}/ams"
    fi
    export PORTAINER_PORTS_ARRAY=(${PORTAINER_PORTS})
    for i in "${!PORTAINER_PORTS_ARRAY[@]}"; do export PORTAINER_PORT_${i}=${PORTAINER_PORTS_ARRAY[${i}]}; done
}

process_docker_compose() {
    DOCKER_COMPOSE=docker-compose.yml
    yq eval-all 'select(fileIndex == 0).'swarm' *d select(fileIndex == 0).docker' \$${DOCKER_COMPOSE} > swarm.yml
    yq eval-all 'select(fileIndex == 0).'compose' *d select(fileIndex == 0).docker' \$${DOCKER_COMPOSE} > compose.yml
    echo yq eval-all 'select(fileIndex == 0).'${PORTAINER_TYPE}' *d select(fileIndex == 0).docker' \$${DOCKER_COMPOSE} | envsubst > ${DOCKER_COMPOSE}
    yq eval-all 'select(fileIndex == 0).'${PORTAINER_TYPE}' *d select(fileIndex == 0).docker' \$${DOCKER_COMPOSE} | envsubst > ${DOCKER_COMPOSE}
}

portainer_deploy() {
    ansi-cat ${DOCKER_COMPOSE}
    PORTAINER_STACK=${PORTAINER_PORTS_ARRAY[0]}-${CI_PROJECT_PATH_SLUG}-${CI_ENVIRONMENT_NAME}
    if [ "$PORTAINER_TYPE" = "swarm" ]; then
        PORTAINER_STACK="swarm-is-not-supported"
    fi
    echo ${PORTAINER_STACK,,} " - NO_DEPLOY_TO_PORTAINER = ${NO_DEPLOY_TO_PORTAINER}"
    if [ "${NO_DEPLOY_TO_PORTAINER}" = "true" ]; then
        echo "Not deploying to Portainer !!! " && exit
    fi
    psu deploy --name=${PORTAINER_STACK,,} --compose-file=${DOCKER_COMPOSE} --user=${PORTAINER_USER} --password=${PORTAINER_PASSWORD} --url=${PORTAINER_HOST} --endpoint=${PORTAINER_ENDPOINT} --verbose --insecure
}

ams_ping() {
    if [ "$__NOPING" = false ]; then
        ams-ping
    else
        air-log INFO "Skipping ams-ping due to --noping flag."
    fi
}

ams-ctx AHS_ORIGIN
ams-ctx AMS_ORIGIN

arg_config "$@"
setup_env

ams-ctx AMS_DEPLOY

process_docker_compose
portainer_deploy
ams_ping
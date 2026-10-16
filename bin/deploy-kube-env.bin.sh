#!/bin/bash

set -e

air-log INFO "AIR_LOG: '${AIR_LOG}'. Options: [INSPECT, DEBUG]"

arg_config() {
    __INSPECT=false
    __DEBUG=false
    __CRYPT=false

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
            --crypt) __CRYPT=true ;;
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

deploy_kube_env() {
    # air-assert ENV ENV_HOME
    air-log INFO "Deploying plain .env files to '${ENV_HOME}'"
    mkdir -p "${ENV_HOME}"
    rm -rf "${ENV_HOME:?}/"*
    #cp -r .opt/* "${ENV_HOME}/"
    air-copy DIR .opt ${ENV_HOME}
    ansi-cmd tree ${ENV_HOME}
    #ls -laR "${ENV_HOME}"
}

deploy_kube_env_crypt() {
    air-log INFO "Encrypting .env files to session-request directory..."
    air-assert ENV PDS_TOKEN
    find .opt/ -type f -name '*.env' | while read -r FILE_PATH; do 
        FILE_NAME=$(basename "${FILE_PATH}")
        FILE_BASE="${FILE_NAME%.*}"
        SESSION_REQUEST_NAME="${FILE_BASE//./-}.env-session-request"
        SESSION_REQUEST_FILE="/cache-volume/session-request/${SESSION_REQUEST_NAME}"

        rm -f "${SESSION_REQUEST_FILE}"

        zip -j -P "${PDS_TOKEN}" "${SESSION_REQUEST_FILE}" "${FILE_PATH}"
    done
}

ams-ctx AHS_ORIGIN
ams-ctx AMS_ORIGIN

arg_config "$@"

if [ "$__CRYPT" = true ]; then
    deploy_kube_env_crypt
else
    deploy_kube_env
fi

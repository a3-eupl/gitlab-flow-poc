#!/bin/bash

set -e

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
            --inspect) __INSPECT=true ;;
            --debug) __DEBUG=true ;;
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

deploy_auth() {
    input="dist/.auth.htpasswd"
    air-copy FILE ${input} ${AUTH_HTPASSWD}
    ansi-cat ${AUTH_HTPASSWD}
}

ams-ctx AHS_ORIGIN
ams-ctx AMS_ORIGIN

arg_config "$@"

deploy_auth

#!/bin/bash

set -e

air-log INFO "AIR_LOG: '${AIR_LOG}'. Options: [INSPECT, DEBUG]"

arg_config() {
    __INSPECT=false
    __DEBUG=false
    __VERSION_NODE=""
    __VERSION_YARN=""

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
            --node=*)
                __VERSION_NODE="${1#*=}"

                if [[ -z "$__VERSION_NODE" ]]; then
                    air-log ERROR "--node requires a version (e.g. --node=24.14.0)"
                    exit 64
                fi
                ;;
            --yarn=*)
                __VERSION_YARN="${1#*=}"

                if [[ -z "$__VERSION_YARN" ]]; then
                    air-log ERROR "--yarn requires a version (e.g. --yarn=1.22.22)"
                    exit 64
                fi
                ;;
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

build_yarn_nuxt() {
    if [[ -z "$__VERSION_NODE" ]]; then
        air-log ERROR "Missing required parameter: --node=<version>"
        exit 64
    fi

    if [[ -z "$__VERSION_YARN" ]]; then
        air-log ERROR "Missing required parameter: --yarn=<version>"
        exit 64
    fi

    em-node use ${__VERSION_NODE}
    em-node yarn ${__VERSION_YARN}

    NODE_ENV=production yarn install --immutable

    yarn build
}

arg_config "$@"
build_yarn_nuxt
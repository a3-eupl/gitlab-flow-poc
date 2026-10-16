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

check_pipeline_source() {
  if [ "${CI_PIPELINE_SOURCE}" != "pipeline" ]; then
    air-log INFO "Skipping further execution. CI_PIPELINE_SOURCE is '${CI_PIPELINE_SOURCE}'."
    air-log INFO "This pipeline is designed to process pipelines with CI_PIPELINE_SOURCE: 'pipeline'."
    exit 0
  fi
}

ams-ctx AHS_ORIGIN

arg_config "$@"
check_pipeline_source

ams-ctx AMS_PIPELINE

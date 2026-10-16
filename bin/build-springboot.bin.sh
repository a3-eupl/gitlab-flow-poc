#!/bin/bash

set -e

air-log INFO "AIR_LOG: '${AIR_LOG}'. Options: [INSPECT, DEBUG]"

arg_config() {
    __INSPECT=false
    __DEBUG=false
    __VERSION_JAVA=""
    __VERSION_MVN=""

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
            --java=*)
                __VERSION_JAVA="${1#*=}"

                if [[ -z "$__VERSION_JAVA" ]]; then
                    air-log ERROR "--java requires a version (e.g. --java=17)"
                    exit 64
                fi
                ;;
            --mvn=*)
                __VERSION_MVN="${1#*=}"

                if [[ -z "$__VERSION_MVN" ]]; then
                    air-log ERROR "--mvn requires a version (e.g. --mvn=3.6)"
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

build_springboot(){ 
    if [[ -z "$__VERSION_JAVA" ]]; then
        air-log ERROR "Missing required parameter: --java=<version>"
        exit 64
    fi

    if [[ -z "$__VERSION_MVN" ]]; then
        air-log ERROR "Missing required parameter: --mvn=<version>"
        exit 64
    fi

    em-java use ${__VERSION_JAVA}
    em-mvn use ${__VERSION_MVN}

    export MAVEN_OPTS="-Dmaven.repo.local=${MVN_HOME}/repository"
    export MAVEN_CONFIG=${MVN_HOME}

    mvn versions:set -DnewVersion=${AMS_DIST} -DgenerateBackupPoms=false
    mvn clean install -DskipITs=true -Dmaven.test.skip=true
}

ams-ctx AHS_ORIGIN

arg_config "$@"
build_springboot

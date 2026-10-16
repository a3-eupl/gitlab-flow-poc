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
repo_clone() {
    #A3_REPO_USER=
    #A3_REPO_EMAIL=
    #A3_REPO_TOKEN=
    #A3_CLASS_DIAGRAM=class-diagram.puml
    export A3_REPO_DIR=${A3_REPO_DIR:-a3-repo}

    req A3_REPO_USER A3_REPO_EMAIL A3_REPO_TOKEN A3_REPO_GIT A3_REPO_DIR A3_CLASS_DIAGRAM

    git config --global user.name "${A3_REPO_USER}"
    git config --global user.email "${A3_REPO_EMAIL}"
    git clone https://gitlab-ci-token:${A3_REPO_TOKEN}@${A3_REPO_GIT} ${A3_REPO_DIR}
}

repo_handler() {
    A3_PUML_DIR=${A3_REPO_DIR}/src/main/@/class-diagram/puml
    A3_PUML_PROPERTIES=${A3_PUML_DIR}/puml.properties

    if [ -n "$CI_COMMIT_TAG" ]; then
      A3_CLASS_DIAGRAM_PUML=cd-${AMS_REVISION%%-*}.puml
    else
      A3_CLASS_DIAGRAM_PUML=cd-${AMS_REVISION%%-*}-${CI_COMMIT_REF_NAME#a3-}.puml
    fi
    air-log VALUE A3_CLASS_DIAGRAM_PUML ${A3_CLASS_DIAGRAM_PUML}

    air-copy FILE ${A3_CLASS_DIAGRAM} ${A3_PUML_DIR}/${A3_CLASS_DIAGRAM_PUML}

    A3_RECORD="$(date +"%y%m%d-%H%M%S"): ${A3_CLASS_DIAGRAM_PUML}"
    air-log VALUE A3_RECORD ${A3_RECORD}

    if grep -q "${A3_CLASS_DIAGRAM_PUML}" ${A3_PUML_PROPERTIES}; then
      sed -i "s/.*${A3_CLASS_DIAGRAM_PUML}.*/${A3_RECORD}/" ${A3_PUML_PROPERTIES}
      A3_GIT_MESSAGE="update class-diagram"
    else
      echo "${A3_RECORD}" >> ${A3_PUML_PROPERTIES}
      A3_GIT_MESSAGE="new class-diagram"
    fi
    air-log VALUE A3_GIT_MESSAGE ${A3_GIT_MESSAGE}

    ansi-cat ${A3_PUML_PROPERTIES}
}

repo_push() {
    cd ${A3_REPO_DIR}
    git add .
    if ! git diff-index --quiet HEAD --; then
        git commit -m "${A3_GIT_MESSAGE} ${A3_CLASS_DIAGRAM_PUML}"
        git push origin main
    else
        air-log WARN "No changes to commit"
    fi
}


ams-ctx AHS_ORIGIN
ams-ctx AMS_ORIGIN

arg_config "$@"
repo_clone
repo_handler
repo_push

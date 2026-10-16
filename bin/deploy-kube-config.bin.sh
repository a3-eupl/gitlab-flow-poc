#!/bin/bash

set -e

source air-arg

deploy_kube_config() {
    LAYER_ROOT=.layer/@kube-config
    mkdir -p "${KUBECONFIG_HOME}"
    rm -rf "${KUBECONFIG_HOME:?}/"*

    ansi-bar COPY "Copy config files to \"${KUBECONFIG_HOME}\""
    air-copy DIR ${LAYER_ROOT} ${KUBECONFIG_HOME}
    ansi-bar COPY COPY Done

    ansi-cmd tree ${KUBECONFIG_HOME}
}

deploy_kube_config_crypt() {
    exit 1
}

ams-ctx AHS_ORIGIN
ams-ctx AMS_ORIGIN

air_arg "$@"

if [ "$__CRYPT" = true ]; then
    deploy_kube_config_crypt
else
    deploy_kube_config
fi

#!/bin/bash

set -e

source air-arg

build_kube_config() {
    SRC_DIR=src
    DIST_DIR=.layer/@kube-config

    rm -rf "${DIST_DIR:?}"/*
    mkdir -p "${DIST_DIR}"

    ansi-bar COPY "Copy Config files to \"${DIST_DIR}\""

    yq eval -o=json '.. | select(tag == "!!str") | {"path": path | join("/"), "value": .}' .kube/kube-config.yml | \
    jq -r '"\(.path): \(.value)"' | \
    while IFS= read -r record; do
        dir="${record%%:*}"
        file="${record#*: }"

        if [[ "$dir" == *"/_file" ]]; then
            dir="${dir%/_file}"
        fi

        mkdir -p ${DIST_DIR}/${dir}
        source_path="${SRC_DIR}/kube-config/${file}"

        if [[ ! -f "$source_path" ]]; then
            air-log ERROR "Unexpected file '${file}' found in directory '${DIST_DIR}/${dir}'. The file name does not match any known configuration."
        else
            #echo ${source_path} '>>>' ${DIST_DIR}/${dir}
            air-copy FILE ${source_path} ${DIST_DIR}/${dir}
        fi
    done

    ansi-bar COPY COPY Done
}

build_kube_config_crypt() {
    exit 1
}

ams-ctx AHS_ORIGIN
ams-ctx AMS_ORIGIN

air_arg "$@"

if [ "$__CRYPT" = true ]; then
    build_kube_config_crypt
else
    build_kube_config
fi

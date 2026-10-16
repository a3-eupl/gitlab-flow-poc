#!/bin/bash

arg_config() {
    AIR_LAYER_FILE=".layer/air-layer.yml"

    if [ ! -f "${AIR_LAYER_FILE}" ]; then
        air-log WARN "AIR_LAYER_FILE '${AIR_LAYER_FILE}' does not exist."
        exit 0
    fi

    ENTRY_POINT="$(yq -r ".air-layer[\"@${AMS_NAME}\"].entry-point // \"\"" "${AIR_LAYER_FILE}")"
    ENTRY_INIT="$( yq -r ".air-layer[\"@${AMS_NAME}\"].entry-init // false" "${AIR_LAYER_FILE}")"
    ENTRY_ADDON="$(yq -r ".air-layer[\"@${AMS_NAME}\"].entry-addon // \"\"" "${AIR_LAYER_FILE}")"

    LAYER_DIR=.layer/@${AMS_NAME}
    AIR_OPT=opt/${AMS_NAME}.air
    AIR_OPT_ENTRY=${AIR_OPT}/entry
    AIR_DIR=${LAYER_DIR}/${AIR_OPT}
    
    SRC_ENTRY_ADDON="/opt/entry/${ENTRY_ADDON}"
    DST_ENTRY_ADDON=${AIR_DIR}/entry

    SRC_ENTRY_POINT="/opt/entry/.bin/entry-point.bin.sh"
    DST_ENTRY_POINT=${DST_ENTRY_ADDON}/entry-point.bin.sh

    SRC_INIT=.init
    DST_INIT=${AIR_DIR}/init

    ansi-bar 1/5 air-layer-config
    echo "----------------------------------------------"
    echo "AMS_NAME:        ${AMS_NAME}"
    echo "PWD:             `pwd`"
    echo "AIR_LAYER_FILE: '${AIR_LAYER_FILE}'"
    echo "----------------------------------------------"
    echo "ENTRY_POINT:     ${ENTRY_POINT}"
    echo "ENTRY_INIT:      ${ENTRY_INIT}"
    echo "ENTRY_ADDON:     ${ENTRY_ADDON}"
    echo "----------------------------------------------"
    echo "LAYER_DIR:       ${LAYER_DIR}"
    echo "AIR_OPT:         ${AIR_OPT}"
    echo "AIR_OPT_ENTRY:   ${AIR_OPT_ENTRY}"
    echo "AIR_DIR:         ${AIR_DIR}"
    echo "----------------------------------------------"
    echo "SRC_ENTRY_ADDON: ${SRC_ENTRY_ADDON}"
    echo "DST_ENTRY_ADDON: ${DST_ENTRY_ADDON}"
    echo "----------------------------------------------"
    echo "SRC_ENTRY_POINT: ${SRC_ENTRY_POINT}"
    echo "DST_ENTRY_POINT: ${DST_ENTRY_POINT}"
    echo "----------------------------------------------"
    echo "SRC_INIT:        ${SRC_INIT}"
    echo "DST_INIT:        ${DST_INIT}"
    echo "----------------------------------------------"
    ansi-bar 1/5 air-layer-config done
}

dir_push() {
    local from
    local to

    from="$(pwd)"

  pushd "$1" > /dev/null || {
        printf '\e[31mDIR-PUSH:\e[0m \e[90m%s\e[0m \e[31m→\e[0m \e[90m%s\e[0m\n' \
      "$from" "$1"

        return 1
    }

    to="$(pwd)"

    printf '\e[36mDIR-PUSH:\e[0m \e[90m%s\e[0m \e[36m→\e[0m \e[36m%s\e[0m\n' \
        "$from" "$to"
}

dir_pop() {
    local from
    local to

    from="$(pwd)"

    popd > /dev/null || return 1

    to="$(pwd)"

    printf '\e[36mDIR-POP:\e[0m  \e[36m%s\e[0m \e[36m←\e[0m \e[90m%s\e[0m\n' \
        "$to" "$from"
}

entry_point() {
    ansi-bar 2/5 entry-point

    if [ -z "${ENTRY_POINT}" ]; then
        air-log WARN "ENTRY-POINT is not set for '@${AMS_NAME}' in '${AIR_LAYER_FILE}'."
        ansi-bar 2/5 entry-point warn
        return 0
    fi

    mkdir -p "$(dirname "${DST_ENTRY_POINT}")"

    ENTRY_POINT="${ENTRY_POINT}" awk '
        $0 == "{{air-layer-entry-point}}" {
            print ENVIRON["ENTRY_POINT"]
            next
        }
        { print }
    ' "${SRC_ENTRY_POINT}" > "${DST_ENTRY_POINT}"
    ansi-cat ${DST_ENTRY_POINT}
    ansi-bar 2/5 entry-point done
}

entry_init() {
    ansi-bar 3/5 "entry-init: ${ENTRY_INIT}"

    if [ "${ENTRY_INIT}" != "true" ]; then
        air-log WARN "ENTRY-INIT is not set for '@${AMS_NAME}' in '${AIR_LAYER_FILE}'."
        ansi-bar 3/5 "entry-init: ${ENTRY_INIT}" warn
        return 0
    fi
    
    air-copy FILE /opt/entry/.bin/entry-init.bin.sh        ${DST_ENTRY_ADDON}/entry-init.bin.sh
    air-copy DIR ${SRC_INIT}                               ${DST_INIT}
    ansi-bar 3/5 "entry-init: ${ENTRY_INIT}" done
}

entry_addon() {
    ansi-bar 4/5 "entry-addon: ${ENTRY_ADDON}"

    if [ -z "${ENTRY_ADDON}" ]; then
        air-log WARN "ENTRY-ADDON is not set for '@${AMS_NAME}' in '${AIR_LAYER_FILE}'."
        ansi-bar 4/5 "entry-addon: ${ENTRY_ADDON}" warn
        return 0
    fi

    if [ ! -d "${SRC_ENTRY_ADDON}" ]; then
        air-log ERROR "SRC_ENTRY_ADDON '${SRC_ENTRY_ADDON}' does not exist or is not a directory."
        return 0
    fi

    case "${ENTRY_ADDON}" in
        postgres)
            air-copy FILE /opt/dist/ams-service-alpine.bin         ${DST_ENTRY_ADDON}/ams-service.bin
            air-copy FILE /opt/entry/.bin/entry-log.bin.sh         ${DST_ENTRY_ADDON}/entry-log.bin.sh
            air-copy DIR ${SRC_ENTRY_ADDON}                        ${DST_ENTRY_ADDON}
        ;;

        keycloak)
            air-copy FILE /opt/dist/ams-service.bin                ${DST_ENTRY_ADDON}/ams-service.bin
            air-copy FILE /opt/entry/.bin/entry-log.bin.sh         ${DST_ENTRY_ADDON}/entry-log.bin.sh
            air-copy DIR ${SRC_ENTRY_ADDON}                        ${DST_ENTRY_ADDON}
        ;;

        springboot)
            air-copy FILE /opt/entry/.bin/entry-log.bin.sh         ${DST_ENTRY_ADDON}/entry-log.bin.sh
            air-copy DIR ${SRC_ENTRY_ADDON}                        ${DST_ENTRY_ADDON}
        ;;

        yarn-nuxt)
            air-copy FILE /opt/entry/.bin/entry-log.bin.sh         ${DST_ENTRY_ADDON}/entry-log.bin.sh
            air-copy DIR ${SRC_ENTRY_ADDON}                        ${DST_ENTRY_ADDON}
        ;;

        yarn-vite)
            air-copy FILE /opt/entry/.bin/entry-log.bin.sh         ${DST_ENTRY_ADDON}/entry-log.bin.sh
            air-copy DIR ${SRC_ENTRY_ADDON}                        ${DST_ENTRY_ADDON}
        ;;

        *)
            echo "ERROR: Unsupported ENTRY_ADDON: ${ENTRY_ADDON}"
            return 1
        ;;
    esac
    ansi-bar 4/5 "entry-addon: ${ENTRY_ADDON}" done
}

air_layer() {
    ansi-bar 5/5 "air-layer"
    if [ -d "${LAYER_DIR}/${AIR_OPT_ENTRY}" ]; then
        mkdir -p ${LAYER_DIR}/usr/local/bin

        echo ------- CHMOD -------

        shopt -s dotglob nullglob

        chmod +x ${LAYER_DIR}/${AIR_OPT_ENTRY}/* 2>/dev/null || true
        ls -la "${LAYER_DIR}/${AIR_OPT_ENTRY}"/*

        echo ------- LN -------

        for bin in ${LAYER_DIR}/${AIR_OPT_ENTRY}/*.bin.sh; do
            air-ln /${AIR_OPT_ENTRY}/$(basename "${bin}") "${LAYER_DIR}/usr/local/bin/$(basename "${bin}" .bin.sh)"
        done

        for bin in ${LAYER_DIR}/${AIR_OPT_ENTRY}/*.bin; do
            air-ln /${AIR_OPT_ENTRY}/$(basename "${bin}") "${LAYER_DIR}/usr/local/bin/$(basename "${bin}" .bin)"
        done

        shopt -u dotglob nullglob
    else
        air-log WARN "ENTRY directory '${LAYER_DIR}/${AIR_OPT_ENTRY}' does not exist."
    fi

    echo ------- TAR -------

    dir_push "${LAYER_DIR}"

    TAR_FILE=".layer/${AMS_NAME}.tar.gz"
    tar -caf "../../${TAR_FILE}" *

    TAR_SIZE=$(du -b "../../${TAR_FILE}" | cut -f1)
    TAR_SIZE_MB=$(awk "BEGIN {printf \"%.3f MB\", ${TAR_SIZE}/1024/1024}")

    echo "TAR_FILE:     ${TAR_FILE}"
    echo "TAR_SIZE:     ${TAR_SIZE_MB}"

    dir_pop

    ansi-bar 5/5 "air-layer" done
    export AMS_LAYER_SIZE=${TAR_SIZE_MB}
}

ams-ctx AHS_ORIGIN

arg_config "$@"

entry_point
entry_init
entry_addon
air_layer

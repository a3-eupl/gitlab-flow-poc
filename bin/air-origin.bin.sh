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

air_origin() {
    AIR_SEMVER=$(cat "$AIR_VERSION" 2>/dev/null || echo "0.0.0")

    CURRENT_VERSION="$AHS_REVISION"
    CURRENT_SEMVER="${CURRENT_VERSION%%-*}"

    air-log INFO "Current AIR version:   $CURRENT_VERSION"
    air-log INFO "Current AIR semver:    $CURRENT_SEMVER"
    air-log INFO "Last known AIR semver: $AIR_SEMVER"

    if [[ "$CURRENT_VERSION" == *-* ]]; then
        air-log ERROR "Expected a clean tag, but found: $CURRENT_VERSION"
        exit 2
    fi

    if [[ "$CURRENT_SEMVER" == "$AIR_SEMVER" ]]; then
        air-log SUCCESS "AIR semver is up to date."
        exit 0
    fi

    LATEST_SEMVER=$(printf "%s\n%s\n" "$CURRENT_SEMVER" "$AIR_SEMVER" | sort -V | tail -n1)

    if [[ "$LATEST_SEMVER" == "$AIR_SEMVER" ]]; then
        air-log ERROR "Newer AIR semver is available: $AIR_SEMVER"
        exit 1
    else
        air-log INFO "Updating AIR semver:   $CURRENT_SEMVER"
        echo "$CURRENT_SEMVER" > "$AIR_VERSION"
        exit 0
    fi
}

ams-ctx AHS_ORIGIN

arg_config "$@"
air_origin

ams-ctx ENV
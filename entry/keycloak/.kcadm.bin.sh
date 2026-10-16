#!/bin/bash
set -e

KCADM_CONFIG=/tmp/.keycloak/kcadm.config
KCADM=/opt/keycloak/bin/kcadm.sh

kcadm() {
    "$KCADM" "$@" --config $KCADM_CONFIG
}

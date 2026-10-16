#!/bin/bash
set -e

# Script to create or update a Keycloak realm.

# Expected environment variables:
#   REALM_ID         - Keycloak realm ID
#   REALM_ARGS       - Keycloak realm arguments (e.g., -s enabled=true)

REALM_ID="$1"
shift
REALM_ARGS=("$@")

source .kcadm

if kcadm get "realms/$REALM_ID" --fields realm >/dev/null 2>&1; then
    echo "Realm update: $REALM_ID"
    kcadm update "realms/$REALM_ID" "${REALM_ARGS[@]}"
else
    echo "Realm create: $REALM_ID"
    kcadm create realms "${REALM_ARGS[@]}"
fi

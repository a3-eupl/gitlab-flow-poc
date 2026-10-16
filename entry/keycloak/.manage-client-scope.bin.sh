#!/bin/bash
set -e

# Script to create or update client scope in Keycloak.

# Args:
#   $1 REALM_ID    - Keycloak realm ID
#   $2 SCOPE_NAME  - Client scope name
#   $3 SCOPE_ARGS  - Keycloak scope arguments

REALM_ID="$1"
SCOPE_NAME="$2"
shift 2
SCOPE_ARGS=("$@")

source .kcadm

# /client-scopes has no server-side "name" query filter (unlike /clients?clientId=),
# so it always returns the full list -- filter by name client-side via CSV instead.
SCOPE_ID_FOUND=$(
    kcadm get client-scopes -r "$REALM_ID" \
        --fields id,name \
        --format csv \
        --noquotes \
    | grep ",${SCOPE_NAME}$" \
    | cut -d',' -f1
)

if [ -z "$SCOPE_ID_FOUND" ]; then
    echo "Client scope create: $SCOPE_NAME"
    kcadm create client-scopes -r "$REALM_ID" "${SCOPE_ARGS[@]}"
else
    echo "Client scope update: $SCOPE_NAME"
    kcadm update "client-scopes/$SCOPE_ID_FOUND" -r "$REALM_ID" "${SCOPE_ARGS[@]}"
fi
#!/bin/bash
set -e

# Assign a client scope to a client as "default" or "optional" in Keycloak.
# Assignment is a plain PUT (idempotent by nature) -- no create-or-update lookup needed.

# Args:
#   $1 REALM_ID    - Keycloak realm ID
#   $2 CLIENT_ID   - Keycloak clientId (not internal UUID)
#   $3 SCOPE_NAME  - Client scope name
#   $4 SCOPE_TYPE  - "default" or "optional"

REALM_ID="$1"
CLIENT_ID="$2"
SCOPE_NAME="$3"
SCOPE_TYPE="$4"

source .kcadm

CLIENT_UUID=$(
    kcadm get clients -r "$REALM_ID" \
        --query clientId="$CLIENT_ID" \
        --fields id \
    | grep -o '"id" : "[^"]*"' \
    | cut -d'"' -f4
)

# /client-scopes has no server-side "name" query filter (unlike /clients?clientId=),
# so it always returns the full list -- filter by name client-side via CSV instead.
SCOPE_UUID=$(
    kcadm get client-scopes -r "$REALM_ID" \
        --fields id,name \
        --format csv \
        --noquotes \
    | grep ",${SCOPE_NAME}$" \
    | cut -d',' -f1
)

case "$SCOPE_TYPE" in
    default)
        echo "Client scope assign (default): $SCOPE_NAME -> $CLIENT_ID"
        kcadm update "clients/$CLIENT_UUID/default-client-scopes/$SCOPE_UUID" -r "$REALM_ID"
        ;;
    optional)
        echo "Client scope assign (optional): $SCOPE_NAME -> $CLIENT_ID"
        kcadm update "clients/$CLIENT_UUID/optional-client-scopes/$SCOPE_UUID" -r "$REALM_ID"
        ;;
    *)
        echo "Unknown scope type: $SCOPE_TYPE (expected 'default' or 'optional')" >&2
        exit 1
        ;;
esac

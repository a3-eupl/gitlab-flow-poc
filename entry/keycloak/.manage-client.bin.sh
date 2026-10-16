#!/bin/bash
set -e

# Script to create or update a Keycloak client in a specified realm.

# Expected environment variables:
#   REALM_ID         - Keycloak realm ID
#   CLIENT_ID        - Keycloak client ID
#   CLIENT_ARGS      - Keycloak client arguments (e.g., -s enabled=true)
#   CLIENT_SECRET    - (optional) client secret, pouzije sa len pri create;
#                      ak je prazdny, Keycloak secret vygeneruje sam.
#                      Pri update sa secret nikdy nemeni.

REALM_ID="$1"
CLIENT_ID="$2"
shift 2
CLIENT_ARGS=("$@")

source .kcadm

CLIENTS_JSON=$(
    kcadm get clients -r "$REALM_ID" \
        --query clientId="$CLIENT_ID" \
        --fields id
)

CLIENT_ID_FOUND=$(
    echo "$CLIENTS_JSON" \
    | grep -o '"id" : "[^"]*"' \
    | cut -d'"' -f4
)

if [ -z "$CLIENT_ID_FOUND" ]; then
    echo "Client create: $CLIENT_ID"

    if [ -n "${CLIENT_SECRET:-}" ]; then
        echo "Client secret: manualne zadany"
        CLIENT_ARGS+=(-s secret="$CLIENT_SECRET")
    else
        echo "Client secret: generuje Keycloak"
    fi

    kcadm create clients -r "$REALM_ID" "${CLIENT_ARGS[@]}"
else
    echo "Client update: $CLIENT_ID (secret sa nemeni)"

    kcadm update "clients/$CLIENT_ID_FOUND" -r "$REALM_ID" "${CLIENT_ARGS[@]}"
fi

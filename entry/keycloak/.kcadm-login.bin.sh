#!/bin/bash
set -e

# Login to Keycloak using kcadm.sh and store the credentials in a config file.

# Expected environment variables:
#   KCADM_CONFIG            - Path to the kcadm config file
#   KEYCLOAK_ADMIN          - Keycloak admin username
#   KEYCLOAK_ADMIN_PASSWORD - Keycloak admin password

source .kcadm

mkdir -p "$(dirname "$KCADM_CONFIG")"

kcadm config credentials \
    --server http://localhost:8080 \
    --realm master \
    --user "$KEYCLOAK_ADMIN" \
    --password "$KEYCLOAK_ADMIN_PASSWORD"

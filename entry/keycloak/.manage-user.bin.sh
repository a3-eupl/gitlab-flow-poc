#!/bin/bash
set -e

# Script to create or update a Keycloak user.

# Expected environment variables:
#   REALM_ID         - Keycloak realm ID
#   USERNAME         - Username updated or created user
#   PASSWORD         - New user password 
#   ROLE             - Role to assign to the user (optional; pass "" to skip and leave user on default-roles-<realm> only)

REALM_ID="$1"
USERNAME="$2"
PASSWORD="$3"
ROLE="$4"
FIRST_NAME="${5:-}"
LAST_NAME="${6:-}"

# USERNAME may already be a full email (e.g. registrationEmailAsUsername realms) --
# only append @ispo.dev when it isn't, to avoid a double-@ address.
if [[ "$USERNAME" == *"@"* ]]; then
    EMAIL="$USERNAME"
else
    EMAIL="${USERNAME}@ispo.dev"
fi

source .kcadm

USER_ID=$(
    kcadm get users \
        -r "$REALM_ID" \
        --query username="$USERNAME" \
        --fields id \
        --format csv \
        --noquotes 2>/dev/null \
    | tail -n1
)

if [ -z "$USER_ID" ]; then
    echo "User create: $USERNAME"

    kcadm create users \
        -r "$REALM_ID" \
        -s username="$USERNAME" \
        -s email="$EMAIL" \
        -s emailVerified=true \
        -s enabled=true \
        ${FIRST_NAME:+-s firstName="$FIRST_NAME"} \
        ${LAST_NAME:+-s lastName="$LAST_NAME"}

    USER_ID=$(
        kcadm get users \
            -r "$REALM_ID" \
            --query username="$USERNAME" \
            --fields id \
            --format csv \
            --noquotes \
        | tail -n1
    )
else
    echo "User update: $USERNAME"

    kcadm update "users/$USER_ID" \
        -r "$REALM_ID" \
        -s email="$EMAIL" \
        -s emailVerified=true \
        -s enabled=true \
        ${FIRST_NAME:+-s firstName="$FIRST_NAME"} \
        ${LAST_NAME:+-s lastName="$LAST_NAME"}
fi

if [ -n "$PASSWORD" ]; then
    kcadm set-password \
        -r "$REALM_ID" \
        --userid "$USER_ID" \
        --new-password "$PASSWORD"
fi

if [ -n "$ROLE" ]; then
    if ! kcadm get "roles/$ROLE" -r "$REALM_ID" >/dev/null 2>&1; then
        echo "Role create: $ROLE"

        kcadm create roles \
            -r "$REALM_ID" \
            -s name="$ROLE"
    fi

    if ! kcadm get "users/$USER_ID/role-mappings/realm" -r "$REALM_ID" \
        | grep -q "\"name\" : \"$ROLE\""; then

        echo "Assign role: $ROLE"

        kcadm add-roles \
            -r "$REALM_ID" \
            --uid "$USER_ID" \
            --rolename "$ROLE"
    fi
else
    echo "Role skip: no role given, user stays on default-roles-${REALM_ID}"
fi
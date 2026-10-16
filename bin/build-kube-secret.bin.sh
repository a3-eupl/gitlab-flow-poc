#!/bin/bash

set -e

source air-arg

LAYER_ROOT=.layer/@${AMS_NAME}
VAR_DIR=var/${AMS_NAME}

mkdir -p ${LAYER_ROOT}/${VAR_DIR}

qa_auth() {
    air-log INFO QA_AUTH
    output="${LAYER_ROOT}/${VAR_DIR}/qa_auth.htpasswd"
    > "$output"

    declare -A usernames
    for file in $(find src/qa-auth -maxdepth 1 -name '*.qa-auth.yml' | sort); do
        #echo "" >> "$output"
        line="# 🏢 $file "
        printf "%-70s\n" "$line" | sed 's/ /#/g' >> "$output"
        #echo "# 🏢 $file" >> "$output"

        while IFS=$'\t' read -r fullname login_file password; do
            if [[ "$fullname" != *.* ]]; then
                air-log ERROR "The user name '$fullname' does not contain a dot."
                exit 1
            fi

            name_part=$(echo "$fullname" | cut -d '.' -f1)
            surname_part=$(echo "$fullname" | cut -d '.' -f2)

            login_calc="${name_part:0:3}-${surname_part:0:3}"

            if [[ "$login_calc" != "$login_file" ]]; then
                air-log ERROR "Login mismatch for '$fullname': calculated '$login_calc' but file specifies '$login_file'."
                exit 2
            fi

            if [[ -n "${usernames[$login_calc]}" ]]; then
                air-log ERROR "The username '$login_calc' already exists (conflict between '${usernames[$login_calc]}' and '$fullname')."
                exit 3
            fi

            usernames["$login_calc"]="$fullname"
            echo "## 🧑‍🔬 $fullname" >> "$output"
            htpasswd -nbB "$login_calc" "$password" >> "$output"
        done < <(yq -r '.["qa-auth"][] | [.name, .login, .pass] | @tsv' "$file")

        #echo " " >> "$output"
    done

    ansi-cat "$output"
    export QA_AUTH_BASE64=$(base64 -w0 "$output")
}
tls_auth() {
    air-log INFO TLS_AUTH
    #air-assert ENV TLS_CRT
    #air-assert ENV TLS_KEY
    export TLS_CRT_BASE64=$(cat "${TLS_CRT}" | base64 -w0)
    export TLS_KEY_BASE64=$(cat "${TLS_KEY}" | base64 -w0)
}

kube_secret_env() {
    VAR_SECRET_ENV="${LAYER_ROOT}/${VAR_DIR}/.env"
    SECRET_ENV=".env"
    cat << EOF > "${VAR_SECRET_ENV}"
QA_AUTH_BASE64=${QA_AUTH_BASE64}
TLS_CRT_BASE64=${TLS_CRT_BASE64}
TLS_KEY_BASE64=${TLS_KEY_BASE64}
EOF
    air-copy FILE "${VAR_SECRET_ENV}" "${SECRET_ENV}"
    air-log INFO "Secret file '${VAR_SECRET_ENV}' was successfully created."
    air-log INFO "Environment file '${SECRET_ENV}' was successfully created."
}

ams-ctx AHS_ORIGIN
ams-ctx AMS_ORIGIN

air_arg "$@"

qa_auth
tls_auth
kube_secret_env

#!/bin/sh

: "${AMS_HOLD:=60}"

nuxt_public(){
  NITRO_JSON_PATH="/opt/${AMS_NAME}/nitro.json"
  if [ ! -f "$NITRO_JSON_PATH" ]; then
      echo "❌ Error: File $NITRO_JSON_PATH was not found!"
      return 10
  fi
  echo "🔄 Loading variables from $NITRO_JSON_PATH..."
  for var_name in $(awk '/"env": \[/,/\]/ { if ($1 ~ /"/ && $1 !~ /"env"/) { gsub(/[",:]/, "", $1); print $1 } }' "$NITRO_JSON_PATH"); do
      eval var_value=\$$var_name
      nuxt_var_name="NUXT_PUBLIC_${var_name}"
      if [ -n "$var_value" ]; then
          export "$nuxt_var_name"="$var_value"
          echo "✅ Exported: $nuxt_var_name=\"$var_value\""
      else
          echo "⚠️ Warning: Original variable \$$var_name is not set in the environment."
      fi
  done
  echo "🚀 Mapping completed!"
}

entry_point() {
  cd /opt/${AMS_NAME}
  nuxt_public || return $?
  node "./server/index.mjs"
  return $?
}

main() {
  export AMS_RUN=$(date +"%y%m%d-%H%M%S")
  echo -e "--🄰🄼🅂-- \e[35m${AMS_RUN} (hold ${AMS_HOLD}s)\e[0m --🄰🄼🅂--"

  entry_point
  EXIT_CODE=$?

  if [ "$EXIT_CODE" -ne 0 ]; then
    echo -e "--🄰🄼🅂-- \e[31m!!! FAILED (exit ${EXIT_CODE}) !!!\e[0m --🄰🄼🅂--"
    if [ "$AMS_HOLD" -gt 0 ]; then
      echo -e "--🄰🄼🅂-- \e[33mApplication failed. Holding for ${AMS_HOLD} seconds before restart...\e[0m --🄰🄼🅂--"
      sleep "$AMS_HOLD"
      echo -e "--🄰🄼🅂-- \e[33mHold time expired. Restarting application...\e[0m --🄰🄼🅂--"
    fi
  fi
  return $EXIT_CODE
}

main "$@"
exit $?
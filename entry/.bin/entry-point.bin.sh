#!/bin/sh

: "${AMS_HOLD:=60}"

{{air-layer-entry-point}}

main() {
  export AMS_RUN=$(date +"%y%m%d-%H%M%S")
  echo -e "--🄰🄼🅂-- \e[35m${AMS_RUN} (hold: ${AMS_HOLD}s | user: $(whoami))\e[0m --🄰🄼🅂--"

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
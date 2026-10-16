#!/bin/bash

air_link_log() {
  local color="$1"
  local status="$2"
  local target="$3"
  local reason="$4"

  printf -- "\e[%sm%-15s\e[0m %-60s \e[%sm%s\e[0m\n" \
    "$color" "LINK-${status^^}" "$target" "$color" "$reason"
}

air_make_link() {
  local src="$1"
  local dest="$2"
  local rel_src

  if [ -z "$src" ] || [ -z "$dest" ]; then
    air_link_log 31 "error:" "link" "missing arguments: use <src> <dest>"
    return 1
  fi

  if ! ln -sfn "$src" "$dest"; then
    air_link_log 31 "error:" "$dest" "linking failed"
    return 1
  fi

  air_link_log 32 "created:" "$dest" "SRC: $src"
}

air_make_link "$1" "$2"

#!/bin/bash

air_copy_log() {
  local color="$1"
  local status="$2"
  local target="$3"
  local source="$4"
  local reason="$5"

    printf -- "\e[%sm%-15s\e[37m %-60s \e[%sm%-60s\e[37m %s\e[0m\n" \
        "$color" "COPY-${status^^}" "$target" "$color" "$source" "$reason"
}

air_copy_file() {
    local src="$1"
    local dest="$2"
    local force="${3:-false}"

    local dest_dir
    local dest_file

    if [ -d "$src" ]; then
        air_copy_log 31 "error:" "$dest" "$src" "is directory .. use copy dir."
        return 1
    fi

    if [ -d "$dest" ]; then
        dest_dir="$dest"
        dest_file="$dest/$(basename "$src")"
    else
        dest_dir="$(dirname "$dest")"
        dest_file="$dest"
    fi

    if ! mkdir -p "$dest_dir"; then
        air_copy_log 31 "error:" "$dest_dir" "$src" "cannot create directory"
        return 1
    fi

    if [ ! -d "$dest_dir" ]; then
        air_copy_log 31 "error:" "$dest_dir" "$src" "is not a directory"
        return 1
    fi

    if [ "$force" = true ] || [ ! -e "$dest_file" ]; then
        if ! cp "$src" "$dest_file"; then
            air_copy_log 31 "error:" "$dest_file" "$src" "copy failed"
            return 1
        fi

        if [ "$force" = true ]; then
            air_copy_log 32 "forced:" "$dest_file" "$src"
        else
            air_copy_log 32 "created:" "$dest_file" "$src"
        fi
    else
        air_copy_log 33 "skipped:" "$dest_file" "$src" "destination file already exists"
    fi
}

air_copy_dir() {
  local src_dir="${1%/}"
  local dest_dir="${2%/}"
  local force="${3:-false}"
  local src_item
  local rel_path
  local dest_item

  if [ ! -d "$src_dir" ]; then
    air_copy_log 31 "error:" "$src_dir" "source directory does not exist"
    return 1
  fi

  if ! mkdir -p "$dest_dir"; then
    air_copy_log 31 "error:" "$dest_dir" "cannot create directory"
    return 1
  fi

  if [ ! -d "$dest_dir" ]; then
    air_copy_log 31 "error:" "$dest_dir" "is not a directory"
    return 1
  fi

  air_copy_log 34 "dir_start:" "$dest_dir" "$src_dir"

  while IFS= read -r -d '' src_item; do
    rel_path="${src_item#$src_dir/}"
    dest_item="$dest_dir/$rel_path"

    if [ -d "$src_item" ]; then
      if ! mkdir -p "$dest_item"; then
        air_copy_log 31 "error:" "$dest_item" "cannot create directory"
        return 1
      fi

      air_copy_log 36 "subdir:" "$dest_item" "$src_item"
      continue
    fi

    air_copy_file "$src_item" "$dest_item" "$force"
  done < <(find "$src_dir" -mindepth 1 -print0)

  air_copy_log 34 "dir_end:" "$dest_dir" "$src_dir"
}

COPY_SCOPE="${1,,}"

case "$COPY_SCOPE" in
  file)
    shift
    air_copy_file "$@"
    ;;

  dir)
    shift
    air_copy_dir "$@"
    ;;

  file-force)
    shift
    air_copy_file "$@" true
    ;;

  dir-force)
    shift
    air_copy_dir "$@" true
    ;;

  *)
    air_copy_log 31 "error:" "copy" "use: file|dir|file-force|dir-force <src> <dest>"
    exit 1
    ;;
esac
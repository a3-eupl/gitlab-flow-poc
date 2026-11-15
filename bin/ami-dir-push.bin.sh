#!/bin/bash

# dir2env <DIRECTORY>
# Packs the specified DIRECTORY into a tar.xz archive,
# encodes it to base64 url-safe string (no padding, single line),
# exports it as an environment variable named AMI_DIR_<DIRNAME_UPPERCASE_NO_DOTS>,
# and creates a file dir-<dirname_lowercase_no_dots> with the export line.

dir_create_placeholder() {
  local dirpath="$1"

  if [[ ! -d "$dirpath" ]]; then
    mkdir -p "$dirpath" || {
      air-log ERROR "Failed to create directory '$dirpath'."
      return 1
    }

    cat <<EOF > "$dirpath/.ami-dir-placeholder"
This directory was created automatically by ami-dir-push because it did not exist.
It contains no original data.
EOF

    air-log WARN "ami-dir-push created placeholder directory: $dirpath"
  fi
}

dir_push() {
  local dirpath="$1"

  dir_create_placeholder "$dirpath" || return $?

  local dirname
  dirname=$(basename "$dirpath")
  # Remove dots and convert to uppercase for variable name
  local varname="AMI_DIR_${dirname//./}"
  varname=${varname^^}

  # For filename: lowercase and remove dots
  local filename="dir-${dirname//./}"
  filename="${filename,,}.env"

  tar -cJf .env2dir.tar.xz -C "$(dirname "$dirpath")" "$dirname" || {
    air-log ERROR "Failed to create archive from directory '$dirpath'."
    return 2
  }

  local encoded
  encoded=$(base64 .env2dir.tar.xz | tr -d '\n' | tr '+/' '-_' | sed 's/=*$//')

  rm -f .env2dir.tar.xz

  export "$varname=$encoded"
  air-log INFO "ami-dir-push exported variable: $varname (directory: $dirpath)"
}

if [[ $# -ne 1 ]]; then
    air-log USAGE "$0 <DIRECTORY_PATH>"
    exit 64
fi

dir_push "$1"
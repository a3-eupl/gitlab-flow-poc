#!/bin/sh

# Easy Manager Link (em-ln)
#
# Usage:
#   em-ln <manager_dir> <manager_bin_dir> [target_dir]
#
# Example:
#   em-ln /opt/enm_versions /opt/enm_versions/24.14.0/bin
#   em-ln /opt/ejm_versions /usr/lib/jvm/current/bin /usr/bin

MANAGER_DIR="$1"
BIN_DIR="$2"
TARGET_DIR="${3:-/usr/local/bin}"

MANAGER_BIN_DIR=${MANAGER_DIR}/${BIN_DIR}

if [ -z "$MANAGER_DIR" ] || [ -z "${MANAGER_BIN_DIR}" ]; then
    air-log USAGE "Usage: $(basename "$0") <manager_dir> <manager_bin_dir> [target_dir]"
    exit 1
fi

[ -d "${MANAGER_BIN_DIR}" ] || {
    air-log ERROR "Directory not found: ${MANAGER_BIN_DIR}"
    exit 2
}

mkdir -p "$TARGET_DIR"

# Remove old links managed by this manager
for link in "$TARGET_DIR"/*; do
    [ -L "$link" ] || continue

    target=$(readlink -f "$link" 2>/dev/null || true)

    case "$target" in
        "$MANAGER_DIR"/*)
            rm -f "${link}"
            #echo DEL: ${link}
            ;;
    esac
done
#exit
# Publish new links
for bin in "${MANAGER_BIN_DIR}"/*; do
    [ -f "$bin" ] || continue
    [ -x "$bin" ] || continue

    #echo NEW: ${bin}
    ln -sfn "$bin" "$TARGET_DIR/$(basename "$bin")"
done

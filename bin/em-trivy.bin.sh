#!/bin/bash
# Easy Manager Trivy

set -e

PACKAGE="trivy"
PACKAGE_VERSION_HINT="0.74.0"
PACKAGE_NAME="${PACKAGE^}"

MANAGER=$(basename "$0")
MANAGER_DIR=${BIN_HOME}/${MANAGER}
MANAGER_BIN=trivy

CURRENT_LINK="${MANAGER_DIR}/current"

ANSI_GREEN="\033[0;32m"
ANSI_ORANGE="\033[0;33m"
ANSI_GRAY="\033[1;30m"
ANSI_RESET="\033[0m"


format_version() {
  local name="$1"
  local size="$2"
  local state="$3"

  local prefix="${ANSI_GRAY}· ${ANSI_RESET}"
  local suffix=" ${ANSI_GRAY}[remote]${ANSI_RESET}"

  if [ "$state" = "installed" ]; then
    prefix="${ANSI_ORANGE}• ${ANSI_RESET}"
    suffix=" ${ANSI_ORANGE}[installed]${ANSI_RESET}"
  fi

  if [ "$state" = "active" ]; then
    prefix="${ANSI_GREEN}* ${ANSI_RESET}"
    suffix=" ${ANSI_GREEN}[active]${ANSI_RESET}"
  fi

  echo -e "${prefix}${name} (${size})${suffix}"
}


restore_active_version() {
  if [ ! -L "${CURRENT_LINK}" ]; then
    return 0
  fi

  local version
  version=$(readlink "${CURRENT_LINK}")

  if [ -z "${version}" ]; then
    return 0
  fi

  if [ ! -d "${MANAGER_DIR}/${version}" ]; then
    air-log WARN "Active ${PACKAGE_NAME} version '${version}' is no longer installed."
    return 0
  fi

  em-ln "${MANAGER_DIR}" "${version}"

  hash -r 2>/dev/null || true
}


install_version() {
  local version=$1
  local url="https://github.com/aquasecurity/trivy/releases/download/v${version}/trivy_${version}_Linux-64bit.tar.gz"
  local archive="/tmp/trivy-${version}.tar.gz"

  if [ -z "${version}" ]; then
    air-log ERROR "${PACKAGE_NAME} version is required (${PACKAGE_VERSION_HINT})."
    exit 11
  fi

  mkdir -p "${MANAGER_DIR}"

  if [ -d "${MANAGER_DIR}/${version}" ]; then
    air-log ERROR "${PACKAGE_NAME} '${version}' is already installed in '${MANAGER_DIR}'."
    exit 13
  fi

  air-log INFO "Downloading ${PACKAGE_NAME} '${version}' from source '${url}' to '${archive}' ..."

  if ! curl -f -L -o "${archive}" "${url}"; then
    air-log ERROR "Failed to download ${PACKAGE_NAME} '${version}'. Check if the version is valid."
    search_versions "${version}"
    exit 14
  fi

  air-log INFO "Extracting ${PACKAGE_NAME} '${version}' from '${archive}' to '${MANAGER_DIR}/${version}' ..."

  mkdir -p "${MANAGER_DIR}/${version}"

  tar -xzf "${archive}" -C "${MANAGER_DIR}/${version}"

  rm -f "${archive}"

  if [ ! -f "${MANAGER_DIR}/${version}/${MANAGER_BIN}" ]; then
    air-log ERROR "${PACKAGE_NAME} binary not found: ${MANAGER_DIR}/${version}/${MANAGER_BIN}"
    rm -rf "${MANAGER_DIR}/${version}"
    exit 15
  fi

  chmod +x "${MANAGER_DIR}/${version}/${MANAGER_BIN}"

  air-log INFO "${PACKAGE_NAME} '${version}' installed successfully in '${MANAGER_DIR}/${version}'."

  use_version "${version}"
}


use_version() {
  local version=$1
  local MANAGER_VER_DIR="${MANAGER_DIR}/${version}"

  if [ -z "${version}" ]; then
    air-log ERROR "${PACKAGE_NAME} version is required (${PACKAGE_VERSION_HINT})."
    exit 21
  fi

  if [ ! -d "${MANAGER_VER_DIR}" ]; then
    air-log WARN "${PACKAGE_NAME} version '${version}' is not installed."
    list_versions
    air-log INFO "Try to install: '${version}'"
    install_version "${version}"
    exit 22
  fi

  # Persist active version.
  # The symlink is stored in the persistent BIN_HOME volume.
  ln -sfn "${version}" "${CURRENT_LINK}"

  # Activate version in the current container.
  em-ln "${MANAGER_DIR}" "${version}"

  hash -r 2>/dev/null || true

  air-log INFO "Successfully switched to ${PACKAGE_NAME} '${version}'."

  "${MANAGER_VER_DIR}/${MANAGER_BIN}" --version
}


list_versions() {
  local active_version=""
  local total_bytes=0

  air-log INFO "Installed ${PACKAGE_NAME} versions:"

  # Read active version from persistent symlink.
  if [ -L "${CURRENT_LINK}" ]; then
    active_version=$(readlink "${CURRENT_LINK}")
  fi

  if [ -d "${MANAGER_DIR}" ]; then
    for version_dir in "${MANAGER_DIR}"/*; do

      [ -d "$version_dir" ] || continue

      local version
      version=$(basename "$version_dir")

      # current is the persistent active-version symlink.
      [ "${version}" = "current" ] && continue

      local size_bytes
      local size_hr
      local state

      size_bytes=$(du -sb "$version_dir" 2>/dev/null | awk '{print $1}')
      total_bytes=$((total_bytes + size_bytes))

      size_hr=$(numfmt --to=iec --suffix=B "$size_bytes" 2>/dev/null)

      state="installed"

      if [ "${version}" = "${active_version}" ]; then
        state="active"
      fi

      format_version "${version}" "${size_hr}" "${state}"
    done

    local total_hr
    total_hr=$(numfmt --to=iec --suffix=B "$total_bytes" 2>/dev/null)

    echo -e "${ANSI_GREEN}Total installed size:${ANSI_RESET} ${total_hr}"
  fi
}


search_versions() {
  local term=$1
  local index_url="https://api.github.com/repos/aquasecurity/trivy/releases"

  if [ -n "${term}" ]; then
    air-log INFO "Fetching online ${PACKAGE_NAME} versions matching '${term}'..."
  else
    air-log INFO "Fetching online ${PACKAGE_NAME} versions..."
  fi

  local versions

  versions=$(
    curl -fsSL "${index_url}?per_page=100" \
      | jq -r '.[].tag_name' \
      | sed 's/^v//' \
      | sort -Vr
  )

  if [ -n "${term}" ]; then
    versions=$(echo "$versions" | grep "^${term}" || true)
  fi

  if [ -z "$versions" ]; then
    air-log WARN "No ${PACKAGE_NAME} versions found for '${term}'"
    return
  fi

  local active_version=""

  if [ -L "${CURRENT_LINK}" ]; then
    active_version=$(readlink "${CURRENT_LINK}")
  fi

  echo "$versions" | while IFS= read -r version; do
    [ -n "${version}" ] || continue

    local state="remote"
    local size="-"

    if [ -d "${MANAGER_DIR}/${version}" ]; then
      state="installed"
      size=$(du -sh "${MANAGER_DIR}/${version}" 2>/dev/null | awk '{print $1}')

      if [ "${version}" = "${active_version}" ]; then
        state="active"
      fi
    fi

    format_version "${version}" "${size}" "${state}"
  done
}


case "$1" in

  install)
    install_version "$2"
    ;;

  use)
    use_version "$2"
    ;;

  list)
    restore_active_version
    list_versions
    ;;

  search)
    restore_active_version
    search_versions "$2"
    ;;

  *)
    air-log USAGE "Easy Manager ${PACKAGE_NAME}"
    air-log USAGE "Usage: ${MANAGER} {install|use|list|search} [version]"
    exit 1
    ;;

esac
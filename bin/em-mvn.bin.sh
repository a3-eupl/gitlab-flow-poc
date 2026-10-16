#!/bin/bash
# Easy Manager Mvn

set -e

PACKAGE="mvn"
PACKAGE_VERSION_HINT="3.6.3"
PACKAGE_NAME="${PACKAGE^}"

MANAGER=$(basename "$0")
MANAGER_DIR=${BIN_HOME}/${MANAGER}
MANAGER_BIN=bin/mvn

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

install_version() {
  local version=$1
  local url="https://archive.apache.org/dist/maven/maven-3/${version}/binaries/apache-maven-${version}-bin.tar.gz"
  local archive="/tmp/maven-${version}.tar.gz"

  if [ -z "${version}" ]; then
    air-log ERROR "${PACKAGE_NAME} version is required (${PACKAGE_VERSION_HINT})."
    exit 11
  fi

  mkdir -p "${MANAGER_DIR}"
  cd "${MANAGER_DIR}" || exit 12

  if [ -d "${version}" ]; then
    air-log ERROR "${PACKAGE_NAME} '${version}' is already installed in '${MANAGER_DIR}'."
    exit 13
  fi

  air-log INFO "Downloading ${PACKAGE_NAME} '${version}' from source '${url}' to '${archive}' ..."

  # Pridané -f pre potlačenie HTTP chýb a -L pre správne presmerovanie (redirect)
  if ! curl -f -L -o "${archive}" "${url}"; then
    air-log ERROR "Failed to download ${PACKAGE_NAME} '${version}'. Check if the version is valid."
    search_versions ${version}
    exit 14
  fi

  air-log INFO "Extracting ${PACKAGE_NAME} '${version}' from '${archive}' to '${MANAGER_DIR}/${version}' ..."
  mkdir -p "${version}"
  tar -xf "${archive}" --strip-components=1 -C "${version}"
  rm -f "${archive}"

  if [ ! -x "${version}/${MANAGER_BIN}" ]; then
    air-log ERROR "${PACKAGE_NAME} binary not found: ${MANAGER_DIR}/${version}/${MANAGER_BIN}"
    rm -rf "${version}"
    exit 15
  fi

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
    list_versions
    exit 22
  fi

  export MAVEN_HOME="${MANAGER_VER_DIR}"
  em-ln ${MANAGER_DIR} ${version}/bin

  # remove old symlink (safe)
#  rm -f /usr/local/bin/mvn

  # IMPORTANT: link whole bin dir behavior via MAVEN_HOME
#  export PATH="$MAVEN_HOME/bin:$PATH"


  # optional global symlink (works but not required)
#  ln -sf "${MANAGER_VER_DIR}/bin/mvn" /usr/local/bin/mvn

  hash -r 2>/dev/null || true

  air-log INFO "Successfully switched to ${PACKAGE_NAME} '${version}'."
  mvn -v
}

list_versions() {
  local active_version=""
  local total_bytes=0

  air-log INFO "Installed ${PACKAGE_NAME} versions:"
    
  if [ -L "/usr/local/bin/mvn" ]; then
    target=$(readlink "/usr/local/bin/mvn")
    active_version=$(echo "$target" | sed -E "s|^${MANAGER_DIR}/([^/]+)/.*|\1|")
  fi

  if [ -d "${MANAGER_DIR}" ]; then
    for dir in "$MANAGER_DIR"/*; do
      [ -d "$dir" ] || continue

      local version size_bytes size_hr state

      version=$(basename "$dir")

      size_bytes=$(du -sb "$dir" 2>/dev/null | awk '{print $1}')
      total_bytes=$((total_bytes + size_bytes))

      size_hr=$(numfmt --to=iec --suffix=B "$size_bytes" 2>/dev/null)

      state="installed"
      [ "${version}" = "$active_version" ] && state="active"

      format_version "${version}" "$size_hr" "$state"
    done

    local total_hr
    total_hr=$(numfmt --to=iec --suffix=B "$total_bytes" 2>/dev/null)

    echo -e "${ANSI_GREEN}Total installed size:${ANSI_RESET} ${total_hr}"
  fi
}

search_versions() {
  local term=$1
  local url="https://archive.apache.org/dist/maven/maven-3/"

  if [ -n "${term}" ]; then
      air-log INFO "Fetching online ${PACKAGE_NAME} versions matching '${term}'..."
  else
      air-log INFO "Fetching online ${PACKAGE_NAME} versions..."
  fi

  local versions
  versions=$(curl -s "$url" | grep -oE '3\.[0-9]+\.[0-9]+' | sort -V | uniq)

  if [ -n "${term}" ]; then
    versions=$(echo "$versions" | grep "${term}" || true)
  fi

  if [ -z "$versions" ]; then
    air-log WARN "No ${PACKAGE_NAME} versions found for '${term}'"
    return
  fi

  for v in $versions; do
    local state="remote"
    local size=""

    if [ -d "${MANAGER_DIR}/${v}" ]; then
      state="installed"
      size=$(du -sh "${MANAGER_DIR}/${v}" 2>/dev/null | awk '{print $1}')
    fi

    format_version "$v" "${size:-"-"}" "$state"
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
    list_versions
    ;;
  search)
    search_versions "$2"
    ;;
  *)
    air-log USAGE "Easy Manager ${PACKAGE_NAME}"
    air-log USAGE "Usage: ${MANAGER} {install|use|list|search} [version]"
    ;;
esac
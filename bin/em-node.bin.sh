#!/bin/bash
# Easy Manager Node

set -e

PACKAGE="node"
PACKAGE_VERSION_HINT="24.14.0"
PACKAGE_NAME="${PACKAGE^}"

MANAGER=$(basename "$0")
MANAGER_DIR=${BIN_HOME}/${MANAGER}
MANAGER_BIN=bin/node

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
  local url="https://unofficial-builds.nodejs.org/download/release/v${version}/node-v${version}-linux-x64-musl.tar.xz"
  local archive="/tmp/node-${version}.tar.gz"

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
  use_version ${version}
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

  em-ln ${MANAGER_DIR} ${version}/bin

  # delete old simlink
#  for bin in /usr/local/bin/*; do
#    if [ -L "$bin" ] && readlink "$bin" | grep -q "^${MANAGER_DIR}"; then
#      rm "$bin"
#    fi
#  done

  # create new simlink
#  for bin in "${MANAGER_VER_DIR}/bin/"*; do
#    ln -sf "$bin" /usr/local/bin/$(basename "$bin")
#  done

  hash -r 2>/dev/null || true

  air-log INFO "Successfully switched to ${PACKAGE_NAME} '${version}'."
  node -v
}

use_yarn() {
  yarn_version=$1
  if ! command -v corepack &> /dev/null; then
    air-log ERROR "Corepack is not installed."
    exit 1
  fi

  corepack enable
  corepack prepare yarn@"$yarn_version" --activate

  air-log INFO "Switched to Yarn ${yarn_version}"
  yarn -v
}

list_versions() {
  local active_version=""
  local total_bytes=0

  air-log INFO "Installed ${PACKAGE_NAME} versions:"
    
  if [ -L "/usr/local/bin/node" ]; then
    local node_link
    node_link=$(readlink "/usr/local/bin/node")
    active_version=$(echo "$node_link" | sed -E "s|^${MANAGER_DIR}/([^/]+)/.*|\1|")
  fi

  if [ -d "${MANAGER_DIR}" ]; then
    for version_dir in "${MANAGER_DIR}"/*; do
      [ -d "$version_dir" ] || continue

      local version size_bytes size_hr state

      version=$(basename "$version_dir")

      size_bytes=$(du -sb "$version_dir" 2>/dev/null | awk '{print $1}')
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
  local index_url="https://nodejs.org/dist/index.tab"

  if ! command -v awk &> /dev/null; then
    air-log ERROR "This command requires 'awk' to parse the list."
    exit 1
  fi

  local active_version=""
  if [ -L "/usr/local/bin/node" ]; then
    local node_link
    node_link=$(readlink "/usr/local/bin/node")
    active_version=$(echo "$node_link" | sed -E "s|^${MANAGER_DIR}/([^/]+)/.*|\1|")
  fi

  if [ -n "${term}" ]; then
      air-log INFO "Fetching online ${PACKAGE_NAME} versions matching '${term}'..."
  else
      air-log INFO "Fetching online ${PACKAGE_NAME} versions..."
  fi

  local raw_versions
  raw_versions=$(curl -s "$index_url" | awk 'NR>1 {
    version = $1;
    lts = $10;
    if (lts != "-") {
      print version " (LTS: " lts ")"
    } else {
      print version
    }
  }' | sed 's/^v//')

  local filtered_versions
  if [ -n "${term}" ]; then
    filtered_versions=$(echo "$raw_versions" | grep "^${term}" || true)
    if [ -z "$filtered_versions" ]; then
      air-log WARN "No ${PACKAGE_NAME} versions found for '${term}'"
      return
    fi
  else
    filtered_versions=$(echo "$raw_versions" | head -n 200)
  fi

  echo "$filtered_versions" | while IFS= read -r line; do
    local v_clean
    v_clean=$(echo "$line" | awk '{print $1}')

    local size=""
    local state="remote"

    if [ -d "${MANAGER_DIR}/${v_clean}" ]; then
      state="installed"

      # size len ak existuje lokálne
      size=$(du -sh "${MANAGER_DIR}/${v_clean}" 2>/dev/null | awk '{print $1}')
    fi

    # ak je aktívna verzia
    if [ "$v_clean" = "$active_version" ]; then
      state="active"
      size=$(du -sh "${MANAGER_DIR}/${v_clean}" 2>/dev/null | awk '{print $1}')
    fi

    # fallback size pre remote
    [ -z "$size" ] && size="-"

    format_version "$v_clean" "$size" "$state"
  done
}

case "$1" in
  install)
    install_version "$2"
    ;;
  use)
    use_version "$2"
    ;;
  yarn)
    use_yarn "$2"
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

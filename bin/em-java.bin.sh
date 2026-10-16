#!/bin/bash
# Easy Manager Java

set -e

PACKAGE="java"
PACKAGE_VERSION_HINT="25.0.3+9"
PACKAGE_NAME="${PACKAGE^}"

MANAGER=$(basename "$0")
MANAGER_DIR=${BIN_HOME}/${MANAGER}
MANAGER_BIN=bin/java

CURRENT_JAVA_LINK="/usr/lib/jvm/current"
DEFAULT_JAVA_LINK="/usr/lib/jvm/default-jvm"

JAVA_VERSIONS_CACHE="/opt/.java_versions_cache"
JAVA_VERSIONS_CACHE_TTL=3600

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
  local url="https://api.adoptium.net/v3/binary/version/jdk-${version}/alpine-linux/x64/jdk/hotspot/normal/eclipse"
  local archive="/tmp/java-${version}.tar.gz"

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
    air-log ERROR "${PACKAGE_NAME} version is required (25.0.3+9)."
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

  mkdir -p "$(dirname "${CURRENT_JAVA_LINK}")"

  # Prelinkovanie hlavných adresárov prostredia
  ln -sfn "${MANAGER_VER_DIR}" "${CURRENT_JAVA_LINK}"
  ln -sfn "${MANAGER_VER_DIR}" "${DEFAULT_JAVA_LINK}"

  em-ln ${MANAGER_DIR} ${version}/bin

  # Výmena symlinkov v /usr/bin pre globálnu dostupnosť
  #ln -sfn "${CURRENT_JAVA_LINK}/bin/java" /usr/bin/java

#  if [ -x "${CURRENT_JAVA_LINK}/bin/javac" ]; then
#    ln -sfn "${CURRENT_JAVA_LINK}/bin/javac" /usr/bin/javac
#  fi

#  if [ -x "${CURRENT_JAVA_LINK}/bin/jar" ]; then
#    ln -sfn "${CURRENT_JAVA_LINK}/bin/jar" /usr/bin/jar
#  fi

  hash -r 2>/dev/null || true

  air-log INFO "Successfully switched to ${PACKAGE_NAME} '${version}'."
  java -version 2>&1 | head -n 1
}

normalize_java_version() {
  echo "$1" | sed 's/ (LTS)$//'
}

list_versions() {
  local active_version=""
  local total_bytes=0

  air-log INFO "Installed ${PACKAGE_NAME} versions:"

  if [ -L "${CURRENT_JAVA_LINK}" ]; then
    local java_link
    java_link=$(readlink "${CURRENT_JAVA_LINK}")
    active_version=$(basename "$java_link")
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

load_java_versions() {

  if [ -f "${JAVA_VERSIONS_CACHE}" ]; then

    local age
    age=$(( $(date +%s) - $(stat -c %Y "${JAVA_VERSIONS_CACHE}") ))

    if [ "$age" -lt "$JAVA_VERSIONS_CACHE_TTL" ]; then
      cat "${JAVA_VERSIONS_CACHE}"
      return 0
    fi
  fi

  mkdir -p "$(dirname "${JAVA_VERSIONS_CACHE}")"

  local versions

  versions=$(
    curl -fsSL "https://api.adoptium.net/v3/info/available_releases" \
    | jq -r '.available_releases[]' \
    | while read -r major; do
        curl -fsSL "https://api.adoptium.net/v3/assets/feature_releases/${major}/ga" \
        | jq -r '.[].version_data.openjdk_version'
      done \
    | sed 's/-LTS$/ (LTS)/' \
    | sort -Vu
  )

  if [ -z "$versions" ]; then
    return 1
  fi

  echo "$versions" > "${JAVA_VERSIONS_CACHE}"

  echo "$versions"
}

search_versions() {
  local term=$1

  if ! command -v jq >/dev/null 2>&1; then
    air-log ERROR "This command requires jq."
    exit 1
  fi

  if [ -n "${term}" ]; then
      air-log INFO "Fetching online ${PACKAGE_NAME} versions matching '${term}'..."
  else
      air-log INFO "Fetching online ${PACKAGE_NAME} versions..."
  fi

  local raw_versions
  raw_versions=$(load_java_versions)

  if [ $? -ne 0 ] || [ -z "$raw_versions" ]; then
    air-log ERROR "Failed to fetch versions from Adoptium."
    exit 1
  fi

  local filtered_versions

  if [ -n "${term}" ]; then
    filtered_versions=$(echo "$raw_versions" | grep "^${term}" || true)

    if [ -z "$filtered_versions" ]; then
      air-log WARN "No ${PACKAGE_NAME} versions found for '${term}'"
      return
    fi
  else
    filtered_versions=$(echo "$raw_versions" | sort -rV | head -n 50)
  fi

  # 👉 active java
  local active_java_real=""
  if [ -e "${CURRENT_JAVA_LINK}" ]; then
    active_java_real=$(readlink -f "${CURRENT_JAVA_LINK}" 2>/dev/null || true)
  fi

  # 👉 installed map
  declare -A installed_versions

  if [ -d "${MANAGER_DIR}" ]; then
    for dir in "${MANAGER_DIR}"/*; do
      [ -d "$dir" ] || continue
      installed_versions["$(basename "$dir")"]="$(readlink -f "$dir")"
    done
  fi

  echo "$filtered_versions" | sort -rV | while IFS= read -r version; do
    [ -n "${version}" ] || continue

    local normalized
    normalized=$(normalize_java_version "${version}")

    local state="remote"
    local size="-"

    # installed check
    if [[ -n "${installed_versions[$normalized]}" ]]; then
      state="installed"

      # active override
      if [[ "${installed_versions[$normalized]}" == "${active_java_real}" ]]; then
        state="active"
      fi

      # size len pre installed
      size=$(du -sh "${MANAGER_DIR}/${normalized}" 2>/dev/null | awk '{print $1}')
    fi

    format_version "${version}" "$size" "$state"
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
    exit 1
    ;;
esac

#!/bin/sh

_log() {
    if command -v air-log >/dev/null 2>&1; then
        command air-log "$@"
    else
        level="$1"
        shift
        echo "[$level] $*"
    fi
}

ansi-bar BIN "Installing Binaries"

if [ -n "$1" ]; then
  SRC="./bin/$1.bin.sh"
  DST=".bin/$1.bin.sh"

  if [ ! -f "$SRC" ]; then
    air-log ERROR "Source file not found: $SRC"
    exit 1
  fi

  if [ -e "$DST" ]; then
    air-log ERROR "File already exists: $DST"
    exit 2
  fi

  mkdir -p .bin
  air-copy FILE "$SRC" "$DST"

  air-log success "Copied: $SRC -> $DST"
  exit 0
fi

OLD_DIR=$(pwd)
DIR_CHANGED=false

if [ -d ".bin" ]; then
  cd .bin && DIR_CHANGED=true
elif [ -d "bin" ]; then
  cd bin && DIR_CHANGED=true
fi

chmod +x .*.bin.sh *.bin.sh 2>/dev/null || true

for script in .*.bin.sh *.bin.sh; do
  [ -e "$script" ] || continue
  
  base_name=$(basename "$script" .bin.sh)
  target_path="/usr/local/bin/$base_name"
  
  if error=$(ln -sf "$(pwd)/$script" "$target_path" 2>&1); then
      _log SUCCESS "Installed: Symbolic link created: $target_path -> $(pwd)/$script"
  else
      _log ERROR "Failed to create symbolic link: $target_path ($error)"
  fi
done

if [ "$DIR_CHANGED" = "true" ]; then
  cd "$OLD_DIR"
fi

if [ -d ".git" ]; then
  cd .git
fi

ansi-bar BIN BIN " "
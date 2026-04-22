#!/usr/bin/env bash
set -euo pipefail

REPO="gfmois/toolbox"
APP_NAME="toolbox"

VERSION="latest"
INSTALL_DIR=""
UPDATE=false
UNINSTALL=false
HELP=false

VERSION_SET=false
INSTALL_DIR_SET=false

usage() {
  cat <<'EOF'
Install Toolbox from GitHub releases.

Usage:
  install-toolbox.sh [--version <version|latest>] [--install-dir <dir>] [--update]
  install-toolbox.sh [--uninstall]

Examples:
  install-toolbox.sh
  install-toolbox.sh --version v1.2.3
  install-toolbox.sh --version=1.2.3
  install-toolbox.sh --install-dir /usr/local/bin
  install-toolbox.sh --install-dir=/usr/local/bin
  install-toolbox.sh --update
  install-toolbox.sh --uninstall
EOF
}

fail() {
  echo "error: $*" >&2
  exit 1
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "required command not found: $1"
  fi
}

download() {
  local url="$1"
  local output="$2"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$output"
    return
  fi

  if command -v wget >/dev/null 2>&1; then
    wget -qO "$output" "$url"
    return
  fi

  fail "neither curl nor wget is available"
}

normalize_arch() {
  case "$1" in
    x86_64|amd64) echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    *)
      fail "unsupported architecture: $1"
      ;;
  esac
}

resolve_tag() {
  local requested="$1"

  if [[ "$requested" == "latest" ]]; then
    local latest_json tag

    if command -v curl >/dev/null 2>&1; then
      latest_json="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest")"
    elif command -v wget >/dev/null 2>&1; then
      latest_json="$(wget -qO- "https://api.github.com/repos/${REPO}/releases/latest")"
    else
      fail "neither curl nor wget is available"
    fi

    tag="$(printf '%s\n' "$latest_json" | sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)"

    if [[ -z "$tag" ]]; then
      fail "failed to resolve latest release tag"
    fi

    echo "$tag"
    return
  fi

  if [[ "$requested" == v* ]]; then
    echo "$requested"
  else
    echo "v${requested}"
  fi
}

test_version_value() {
  local value="$1"

  [[ -n "$value" ]] || fail "version cannot be empty"

  case "$value" in
    --update|--uninstall|--help|--version|--install-dir|-h)
      fail "invalid version value '$value'. Use a real version like '1.2.3', 'v1.2.3' or 'latest'."
      ;;
  esac
}

find_installed_toolbox() {
  local candidates=()
  local path_candidate=""

  if path_candidate="$(command -v toolbox 2>/dev/null)"; then
    if [[ -n "$path_candidate" && -f "$path_candidate" ]]; then
      candidates+=("$path_candidate")
    fi
  fi

  # Rutas típicas
  candidates+=(
    "${HOME}/.local/bin/toolbox"
    "${HOME}/bin/toolbox"
    "/usr/local/bin/toolbox"
  )

  local candidate
  for candidate in "${candidates[@]}"; do
    if [[ -n "$candidate" && -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        HELP=true
        shift
        ;;
      --update)
        UPDATE=true
        shift
        ;;
      --uninstall)
        UNINSTALL=true
        shift
        ;;
      --version)
        [[ $# -ge 2 ]] || fail "missing value for --version"
        VERSION="$2"
        VERSION_SET=true
        shift 2
        ;;
      --install-dir)
        [[ $# -ge 2 ]] || fail "missing value for --install-dir"
        INSTALL_DIR="$2"
        INSTALL_DIR_SET=true
        shift 2
        ;;
      --version=*)
        VERSION="${1#*=}"
        VERSION_SET=true
        shift
        ;;
      --install-dir=*)
        INSTALL_DIR="${1#*=}"
        INSTALL_DIR_SET=true
        shift
        ;;
      *)
        fail "unknown argument: $1"
        ;;
    esac
  done
}

parse_args "$@"

if [[ "$HELP" == true ]]; then
  usage
  exit 0
fi

if [[ "$UPDATE" == true && "$UNINSTALL" == true ]]; then
  fail "--update cannot be combined with --uninstall"
fi

if [[ "$UNINSTALL" == true ]]; then
  [[ "$VERSION_SET" == false ]] || fail "--uninstall cannot be combined with --version"
  [[ "$INSTALL_DIR_SET" == false ]] || fail "--uninstall cannot be combined with --install-dir"

  installed_binary="$(find_installed_toolbox || true)"
  [[ -n "$installed_binary" ]] || fail "toolbox is not installed or could not be located"

  echo "Uninstalling toolbox from ${installed_binary}"
  rm -f "$installed_binary"

  resolved_install_dir="$(dirname "$installed_binary")"

  if [[ -d "$resolved_install_dir" ]] && [[ -z "$(find "$resolved_install_dir" -mindepth 1 -maxdepth 1 2>/dev/null)" ]]; then
    rmdir "$resolved_install_dir" 2>/dev/null || true
    if [[ ! -d "$resolved_install_dir" ]]; then
      echo "Removed empty directory ${resolved_install_dir}"
    fi
  fi

  echo "Toolbox uninstalled successfully"
  exit 0
fi

test_version_value "$VERSION"

if [[ "$UPDATE" == true ]]; then
  [[ "$VERSION_SET" == false ]] || fail "--update cannot be combined with --version"
  [[ "$INSTALL_DIR_SET" == false ]] || fail "--update cannot be combined with --install-dir"

  installed_binary="$(find_installed_toolbox || true)"
  [[ -n "$installed_binary" ]] || fail "toolbox is not currently installed or could not be located"

  INSTALL_DIR="$(dirname "$installed_binary")"
  VERSION="latest"
  ACTION="updated"

  echo "Updating existing toolbox installation in ${INSTALL_DIR}"
else
  if [[ -z "$INSTALL_DIR" ]]; then
    INSTALL_DIR="${HOME}/.local/bin"
  fi
  ACTION="installed"
fi

[[ -n "$INSTALL_DIR" ]] || fail "install directory cannot be empty"

require_cmd tar
require_cmd install
require_cmd mktemp

os_name="$(uname -s)"
case "$os_name" in
  Linux) os="linux" ;;
  Darwin) os="darwin" ;;
  *)
    fail "unsupported OS: $os_name (use install-toolbox.ps1 on Windows)"
    ;;
esac

arch="$(normalize_arch "$(uname -m)")"
tag="$(resolve_tag "$VERSION")"
version_no_v="${tag#v}"
asset_name="${APP_NAME}_v${version_no_v}_${os}_${arch}.tar.gz"
download_url="https://github.com/${REPO}/releases/download/${tag}/${asset_name}"

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

archive_path="${tmp_dir}/${asset_name}"

echo "Downloading ${download_url}"
download "$download_url" "$archive_path"

echo "Extracting archive"
tar -xzf "$archive_path" -C "$tmp_dir"

binary_source="${tmp_dir}/bin/toolbox"
[[ -f "$binary_source" ]] || fail "toolbox binary not found in downloaded archive"

mkdir -p "$INSTALL_DIR"
install -m 0755 "$binary_source" "${INSTALL_DIR}/toolbox"

echo "Toolbox ${ACTION} at ${INSTALL_DIR}/toolbox"
echo "Run: toolbox --version"
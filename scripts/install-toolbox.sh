#!/usr/bin/env bash
set -euo pipefail

REPO="gfmois/toolbox"
VERSION="latest"
INSTALL_DIR="${HOME}/.local/bin"
UPDATE=false
VERSION_SET=false
INSTALL_DIR_SET=false
ACTION="installed"

usage() {
  cat <<'EOF'
Install Toolbox from GitHub releases.

Usage:
  install-toolbox.sh [--version <version|latest>] [--install-dir <dir>] [--update]

Examples:
  install-toolbox.sh
  install-toolbox.sh --version v1.2.3
  install-toolbox.sh --install-dir /usr/local/bin
  install-toolbox.sh --update
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: required command not found: $1" >&2
    exit 1
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

  echo "error: neither curl nor wget is available" >&2
  exit 1
}

normalize_arch() {
  case "$1" in
    x86_64|amd64) echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    *)
      echo "error: unsupported architecture: $1" >&2
      exit 1
      ;;
  esac
}

resolve_tag() {
  local requested="$1"
  if [[ "$requested" == "latest" ]]; then
    local latest_json
    if command -v curl >/dev/null 2>&1; then
      latest_json="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest")"
    elif command -v wget >/dev/null 2>&1; then
      latest_json="$(wget -qO- "https://api.github.com/repos/${REPO}/releases/latest")"
    else
      echo "error: neither curl nor wget is available" >&2
      exit 1
    fi
    local tag
    tag="$(printf '%s\n' "$latest_json" | sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)"
    if [[ -z "$tag" ]]; then
      echo "error: failed to resolve latest release tag" >&2
      exit 1
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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="${2:-}"
      VERSION_SET=true
      shift 2
      ;;
    --install-dir)
      INSTALL_DIR="${2:-}"
      INSTALL_DIR_SET=true
      shift 2
      ;;
    --update)
      UPDATE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$VERSION" ]]; then
  echo "error: version cannot be empty" >&2
  exit 1
fi

if [[ -z "$INSTALL_DIR" ]]; then
  echo "error: install directory cannot be empty" >&2
  exit 1
fi

if [[ "$UPDATE" == true ]]; then
  if [[ "$VERSION_SET" == true ]]; then
    echo "error: --update cannot be combined with --version" >&2
    exit 1
  fi

  if [[ "$INSTALL_DIR_SET" == true ]]; then
    echo "error: --update cannot be combined with --install-dir" >&2
    exit 1
  fi

  installed_binary="$(type -P toolbox || true)"
  if [[ -z "$installed_binary" ]]; then
    echo "error: toolbox is not currently installed or not on PATH" >&2
    exit 1
  fi

  INSTALL_DIR="$(dirname "$installed_binary")"
  VERSION="latest"
  ACTION="updated"
  echo "Updating existing toolbox installation in ${INSTALL_DIR}"
fi

require_cmd tar
require_cmd install

os_name="$(uname -s)"
case "$os_name" in
  Linux) os="linux" ;;
  Darwin) os="darwin" ;;
  *)
    echo "error: unsupported OS: $os_name (use install-toolbox.ps1 on Windows)" >&2
    exit 1
    ;;
esac

arch="$(normalize_arch "$(uname -m)")"
tag="$(resolve_tag "$VERSION")"
version_no_v="${tag#v}"
asset_name="toolbox_v${version_no_v}_${os}_${arch}.tar.gz"
download_url="https://github.com/${REPO}/releases/download/${tag}/${asset_name}"

tmp_dir="$(mktemp -d)"
cleanup() { rm -rf "$tmp_dir"; }
trap cleanup EXIT

archive_path="${tmp_dir}/${asset_name}"
download "$download_url" "$archive_path"
tar -xzf "$archive_path" -C "$tmp_dir"

binary_source="${tmp_dir}/bin/toolbox"
if [[ ! -f "$binary_source" ]]; then
  echo "error: toolbox binary not found in downloaded archive" >&2
  exit 1
fi

mkdir -p "$INSTALL_DIR"
install -m 0755 "$binary_source" "${INSTALL_DIR}/toolbox"

echo "Toolbox ${ACTION} at ${INSTALL_DIR}/toolbox"
echo "Run: toolbox --version"

#!/bin/sh

set -eu

silex_repository="Matanek/Silex"
silex_system=$(uname -s)
silex_machine=$(uname -m)

case "$silex_system:$silex_machine" in
    Darwin:arm64) silex_platform="macos-arm64" ;;
    Darwin:x86_64|Darwin:amd64) silex_platform="macos-x64" ;;
    Linux:aarch64|Linux:arm64) silex_platform="linux-arm64" ;;
    Linux:x86_64|Linux:amd64) silex_platform="linux-x64" ;;
    *)
        echo "silex: unsupported host $silex_system $silex_machine; expected macOS or Linux on ARM64 or x64" >&2
        exit 1
        ;;
esac

if [ -z "${HOME:-}" ] && [ -z "${SILEX_INSTALL_DIR:-}" ]; then
    echo "silex: HOME is not set; set SILEX_INSTALL_DIR explicitly" >&2
    exit 1
fi

silex_install_dir=${SILEX_INSTALL_DIR:-"$HOME/.local/bin"}
silex_release=${SILEX_VERSION:-latest}
silex_asset="silex-$silex_platform.tar.gz"
silex_checksum="$silex_asset.sha256"

if [ -n "${SILEX_RELEASE_URL:-}" ]; then
    silex_release_url=${SILEX_RELEASE_URL%/}
elif [ "$silex_release" = "latest" ]; then
    silex_release_url="https://github.com/$silex_repository/releases/latest/download"
else
    case "$silex_release" in
        v*) silex_tag=$silex_release ;;
        *) silex_tag="v$silex_release" ;;
    esac
    silex_release_url="https://github.com/$silex_repository/releases/download/$silex_tag"
fi

silex_temporary=$(mktemp -d "${TMPDIR:-/tmp}/silex-install.XXXXXX")
silex_staged=""
trap 'rm -rf "$silex_temporary"; if [ -n "$silex_staged" ]; then rm -f "$silex_staged"; fi' EXIT HUP INT TERM

curl -fL "$silex_release_url/$silex_asset" -o "$silex_temporary/$silex_asset"
curl -fL "$silex_release_url/$silex_checksum" -o "$silex_temporary/$silex_checksum"

(
    cd "$silex_temporary"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum -c "$silex_checksum"
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 -c "$silex_checksum"
    else
        echo "silex: sha256sum or shasum is required to verify the download" >&2
        exit 1
    fi
    tar -xzf "$silex_asset"
)

mkdir -p "$silex_install_dir"
silex_staged="$silex_install_dir/.silex-install.$$"
install -m 755 "$silex_temporary/silex-$silex_platform/bin/silex" "$silex_staged"
mv -f "$silex_staged" "$silex_install_dir/silex"
silex_staged=""

echo "silex: installed $silex_install_dir/silex"
case ":${PATH:-}:" in
    *":$silex_install_dir:"*) ;;
    *) echo "silex: add $silex_install_dir to PATH before invoking silex" ;;
esac
echo "silex: run 'silex setup' before compiling HLSL shaders"

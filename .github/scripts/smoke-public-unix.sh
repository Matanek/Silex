#!/bin/sh

set -eu

target=$1
version=$2

case "$target:$(uname -s):$(uname -m)" in
    macos-arm64:Darwin:arm64) ;;
    macos-x64:Darwin:x86_64) ;;
    linux-arm64:Linux:aarch64|linux-arm64:Linux:arm64) ;;
    linux-x64:Linux:x86_64) ;;
    *)
        echo "silex: installer smoke target $target does not match host $(uname -s) $(uname -m)" >&2
        exit 1
        ;;
esac

export HOME="$RUNNER_TEMP/home"
export SILEX_INSTALL_DIR="$RUNNER_TEMP/bin"
export SILEX_VERSION="$version"
mkdir -p "$HOME"
curl -fsSL https://raw.githubusercontent.com/Matanek/Silex/main/install.sh | sh

silex="$SILEX_INSTALL_DIR/silex"
"$silex" --version
"$silex" targets | grep -F "$target (host)"
"$silex" setup
source="$GITHUB_WORKSPACE/Tests/Native/DistributionSmoke.sx"
compiled="$RUNNER_TEMP/distribution-smoke"
"$silex" compile "$source" --release -o "$compiled"
test "$("$compiled")" = "silex distribution ready"
test "$("$silex" run "$source" --release)" = "silex distribution ready"
"$silex" test "$source"

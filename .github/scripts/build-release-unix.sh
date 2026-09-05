#!/bin/sh

set -eu

target=$1
zig_url=$2
zig_sha256=$3
zig_directory=$4

case "$target:$(uname -s):$(uname -m)" in
    macos-arm64:Darwin:arm64) ;;
    macos-x64:Darwin:x86_64) ;;
    linux-arm64:Linux:aarch64|linux-arm64:Linux:arm64) ;;
    linux-x64:Linux:x86_64) ;;
    *)
        echo "silex: release target $target does not match host $(uname -s) $(uname -m)" >&2
        exit 1
        ;;
esac

archive="$RUNNER_TEMP/zig.tar.xz"
curl -fL "$zig_url" -o "$archive"
printf '%s  %s\n' "$zig_sha256" "$archive" | if command -v sha256sum >/dev/null 2>&1; then
    sha256sum -c -
else
    shasum -a 256 -c -
fi
tar -xJf "$archive" -C "$RUNNER_TEMP"
PATH="$RUNNER_TEMP/$zig_directory:$PATH"
export PATH

build_prefix="$RUNNER_TEMP/silex-prefix"
zig build -Doptimize=ReleaseFast -Dcpu=baseline \
    --prefix "$build_prefix" \
    --build-file Toolchain/build.zig

root="$RUNNER_TEMP/silex-$target"
mkdir -p "$root/bin"
cp "$build_prefix/bin/silex" "$root/bin/silex"
cp LICENSE NOTICE README.md "$root/"

case "$target" in
    macos-arm64)
        file "$root/bin/silex" | grep -E 'Mach-O 64-bit executable arm64'
        test "$(lipo -archs "$root/bin/silex")" = "arm64"
        ;;
    macos-x64)
        file "$root/bin/silex" | grep -E 'Mach-O 64-bit executable x86_64'
        test "$(lipo -archs "$root/bin/silex")" = "x86_64"
        ;;
    linux-arm64)
        file "$root/bin/silex" | grep -E 'ELF 64-bit.*(ARM aarch64|ARM64)'
        readelf -h "$root/bin/silex" | grep -E 'Machine:.*AArch64'
        ;;
    linux-x64)
        file "$root/bin/silex" | grep -E 'ELF 64-bit.*x86-64'
        readelf -h "$root/bin/silex" | grep -E 'Machine:.*X86-64'
        ;;
esac

release_file="silex-$target.tar.gz"
tar -C "$RUNNER_TEMP" -czf "$release_file" "silex-$target"
if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$release_file" > "$release_file.sha256"
else
    shasum -a 256 "$release_file" > "$release_file.sha256"
fi

python3 -m http.server 8765 --bind 127.0.0.1 --directory "$GITHUB_WORKSPACE" \
    > "$RUNNER_TEMP/silex-release-http.log" 2>&1 &
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true' EXIT HUP INT TERM
attempt=0
until curl -fsS "http://127.0.0.1:8765/$release_file.sha256" > /dev/null; do
    attempt=$((attempt + 1))
    if [ "$attempt" -ge 20 ]; then
        cat "$RUNNER_TEMP/silex-release-http.log" >&2
        exit 1
    fi
    sleep 1
done

export HOME="$RUNNER_TEMP/home"
export SILEX_INSTALL_DIR="$RUNNER_TEMP/bin"
export SILEX_RELEASE_URL="http://127.0.0.1:8765"
mkdir -p "$HOME"
sh "$GITHUB_WORKSPACE/install.sh"

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

kill "$server_pid"
wait "$server_pid" 2>/dev/null || true
trap - EXIT HUP INT TERM

#!/bin/sh
set -eu

silex=$1
output_root=$2
repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
mkdir -p "$output_root"

for mode in debug release; do
    executable="$output_root/signed-storage-$mode"
    case "$(uname -s)" in
        MINGW*|MSYS*|CYGWIN*) executable="$executable.exe" ;;
    esac
    "$silex" compile --backend native \
        "$repository_root/Tests/Native/InteropSignedStorage.sx" \
        "--$mode" --nocache -o "$executable"
    output=$("$executable")
    test "$output" = 'Signed interop storage : OK'
    printf 'PASS signed C storage %s\n' "$mode"
done

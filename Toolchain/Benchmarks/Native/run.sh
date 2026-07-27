#!/bin/sh
set -eu

silex_bin=$1
benchmark_dir=$2
output_dir=.zig-cache/benchmark-native
mkdir -p "$output_dir"

report="$output_dir/report.txt"
{
    echo "Silex native benchmark"
    echo "host: $(uname -s)-$(uname -m)"
    echo "clang: $(clang++ --version | sed -n '1p')"

    for workload in Arithmetic Objects; do
        stem=$(echo "$workload" | tr '[:upper:]' '[:lower:]')
        debug_bin="$output_dir/$stem-debug"
        release_bin="$output_dir/$stem-release"
        clang_bin="$output_dir/$stem-clang"

        /usr/bin/time -p "$silex_bin" compile "$benchmark_dir/$workload.sx" -d -o "$debug_bin" 2> "$output_dir/$stem-debug-compile.time"
        /usr/bin/time -p "$silex_bin" compile "$benchmark_dir/$workload.sx" -r -o "$release_bin" 2> "$output_dir/$stem-release-compile.time"
        /usr/bin/time -p clang++ -std=c++23 -O2 "$benchmark_dir/$workload.cpp" -o "$clang_bin" 2> "$output_dir/$stem-clang-compile.time"

        debug_output=$($debug_bin)
        release_output=$($release_bin)
        clang_output=$($clang_bin)
        if [ "$debug_output" != "$release_output" ] || [ "$release_output" != "$clang_output" ]; then
            echo "$workload outputs differ" >&2
            exit 1
        fi

        /usr/bin/time -p "$debug_bin" > /dev/null 2> "$output_dir/$stem-debug-run.time"
        /usr/bin/time -p "$release_bin" > /dev/null 2> "$output_dir/$stem-release-run.time"
        /usr/bin/time -p "$clang_bin" > /dev/null 2> "$output_dir/$stem-clang-run.time"

        echo "workload: $workload"
        echo "result: $release_output"
        echo "sizes:"
        wc -c "$debug_bin" "$release_bin" "$clang_bin"
        echo "compile times:"
        sed 's/^/  debug /' "$output_dir/$stem-debug-compile.time"
        sed 's/^/  release /' "$output_dir/$stem-release-compile.time"
        sed 's/^/  clang /' "$output_dir/$stem-clang-compile.time"
        echo "run times:"
        sed 's/^/  debug /' "$output_dir/$stem-debug-run.time"
        sed 's/^/  release /' "$output_dir/$stem-release-run.time"
        sed 's/^/  clang /' "$output_dir/$stem-clang-run.time"
    done
} > "$report"

cat "$report"

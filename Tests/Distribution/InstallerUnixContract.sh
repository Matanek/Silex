#!/bin/sh

set -eu

repository_root=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
temporary=$(mktemp -d "${TMPDIR:-/tmp}/silex-installer-contract.XXXXXX")
trap 'rm -rf "$temporary"' EXIT HUP INT TERM

mkdir -p "$temporary/bin"

cat > "$temporary/bin/uname" <<'EOF'
#!/bin/sh
case "${1:-}" in
    -s) printf '%s\n' "$TEST_UNAME_SYSTEM" ;;
    -m) printf '%s\n' "$TEST_UNAME_MACHINE" ;;
    *) exit 2 ;;
esac
EOF

cat > "$temporary/bin/curl" <<'EOF'
#!/bin/sh
for argument do
    case "$argument" in
        http://*|https://*) printf '%s\n' "$argument" > "$TEST_CURL_LOG" ;;
    esac
done
exit 97
EOF

chmod +x "$temporary/bin/uname" "$temporary/bin/curl"

check_host() {
    system=$1
    machine=$2
    expected=$3
    log="$temporary/curl.log"
    stderr="$temporary/stderr.log"
    : > "$log"
    set +e
    PATH="$temporary/bin:/usr/bin:/bin" \
        TEST_UNAME_SYSTEM="$system" \
        TEST_UNAME_MACHINE="$machine" \
        TEST_CURL_LOG="$log" \
        HOME="$temporary/home" \
        sh "$repository_root/install.sh" > /dev/null 2> "$stderr"
    status=$?
    set -e
    test "$status" -eq 97
    grep -F "/silex-$expected.tar.gz" "$log" > /dev/null
}

check_host Darwin arm64 macos-arm64
check_host Darwin x86_64 macos-x64
check_host Linux aarch64 linux-arm64
check_host Linux x86_64 linux-x64

set +e
PATH="$temporary/bin:/usr/bin:/bin" \
    TEST_UNAME_SYSTEM=FreeBSD \
    TEST_UNAME_MACHINE=x86_64 \
    TEST_CURL_LOG="$temporary/curl.log" \
    HOME="$temporary/home" \
    sh "$repository_root/install.sh" > /dev/null 2> "$temporary/unsupported.log"
status=$?
set -e
test "$status" -eq 1
grep -F "unsupported host FreeBSD x86_64" "$temporary/unsupported.log" > /dev/null

printf '%s\n' "Unix installer target contract passed"

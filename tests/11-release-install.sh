#!/bin/sh
#
# Release package and installer test (scripts/release-package.sh,
# scripts/install.sh).
#
# Tier: tool-gated (tar, gzip, sha256sum, python3, and curl or wget). Builds a
# throwaway build tree, packages it, and exercises the installer from a local
# tarball and over a loopback HTTP server, including the refusals: a tampered
# tarball and a missing SHA256SUMS. No outside network is used.
set -eu

DIRECTORY_SCRIPT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$DIRECTORY_SCRIPT/.." && pwd)

. "$DIRECTORY_SCRIPT/lib/test_helpers.sh"
for tool_name in tar gzip sha256sum python3; do
    skip_unless_tool "$tool_name"
done
if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    skip_test 'neither curl nor wget is available'
fi

fail() {
    echo "11-release-install: $1" >&2
    exit 1
}

DIRECTORY_TEST=$(mktemp -d)
PID_SERVER=
cleanup() {
    if [ -n "$PID_SERVER" ]; then
        kill "$PID_SERVER" 2>/dev/null || true
    fi
    rm -rf "$DIRECTORY_TEST"
}
trap cleanup EXIT HUP INT TERM

# Interface check: both scripts are POSIX shell.
sh -n "$REPOSITORY_ROOT/scripts/release-package.sh" || fail 'release-package.sh is not POSIX shell'
sh -n "$REPOSITORY_ROOT/scripts/install.sh" || fail 'install.sh is not POSIX shell'

DIRECTORY_BUILD="$DIRECTORY_TEST/build"
DIRECTORY_RELEASE="$DIRECTORY_TEST/release"
mkdir -p "$DIRECTORY_BUILD/bin" "$DIRECTORY_BUILD/share"
printf '#!/bin/sh\necho demo\n' > "$DIRECTORY_BUILD/bin/demo"
chmod 755 "$DIRECTORY_BUILD/bin/demo"
printf 'demo data\n' > "$DIRECTORY_BUILD/share/demo.txt"
printf '%s\n' '1.0.0' > "$DIRECTORY_BUILD/VERSION"

echo '=== the package is made from the build tree ==='
DIRECTORY_RELEASE="$DIRECTORY_RELEASE" PROJECT_NAME=demo \
    sh "$REPOSITORY_ROOT/scripts/release-package.sh" "$DIRECTORY_BUILD" >/dev/null

case "$(uname -m)" in
    x86_64 | amd64)
        ARCHITECTURE=x86_64
        ;;
    aarch64 | arm64)
        ARCHITECTURE=aarch64
        ;;
    *)
        fail "no test expectation for machine $(uname -m)"
        ;;
esac
FILE_TARBALL="$DIRECTORY_RELEASE/demo-linux-$ARCHITECTURE.tar.gz"

[ -f "$FILE_TARBALL" ] || fail 'the tarball was not written'
for file_expected in SHA256SUMS VERSION RELEASE-NOTES.md; do
    [ -f "$DIRECTORY_RELEASE/$file_expected" ] || fail "the package is missing $file_expected"
done
[ "$(cat "$DIRECTORY_RELEASE/VERSION")" = '1.0.0' ] || fail 'the packaged version is wrong'

echo '=== packing the same build twice is deterministic ==='
digest_first=$(sha256sum "$FILE_TARBALL" | cut -d' ' -f1)
DIRECTORY_RELEASE="$DIRECTORY_RELEASE" PROJECT_NAME=demo \
    sh "$REPOSITORY_ROOT/scripts/release-package.sh" "$DIRECTORY_BUILD" >/dev/null
digest_second=$(sha256sum "$FILE_TARBALL" | cut -d' ' -f1)
[ "$digest_first" = "$digest_second" ] || fail 'packing the same build twice produced different bytes'

echo '=== a local tarball installs after verification ==='
PREFIX="$DIRECTORY_TEST/prefix-local" TARBALL="$FILE_TARBALL" \
    sh "$REPOSITORY_ROOT/scripts/install.sh" >/dev/null
[ -x "$DIRECTORY_TEST/prefix-local/bin/demo" ] || fail 'the local install produced no program'
[ -f "$DIRECTORY_TEST/prefix-local/share/demo.txt" ] || fail 'the local install produced no share file'

echo '=== the installer fetches over loopback HTTP ==='
PORT=$((8000 + ($$ % 1000)))
(cd "$DIRECTORY_RELEASE" && python3 -m http.server "$PORT" --bind 127.0.0.1 >/dev/null 2>&1) &
PID_SERVER=$!
sleep 1
PREFIX="$DIRECTORY_TEST/prefix-http" RELEASE_URL="http://127.0.0.1:$PORT" PROJECT_NAME=demo \
    sh "$REPOSITORY_ROOT/scripts/install.sh" >/dev/null \
    || fail 'the HTTP install failed'
[ -x "$DIRECTORY_TEST/prefix-http/bin/demo" ] || fail 'the HTTP install produced no program'
kill "$PID_SERVER" 2>/dev/null || true
PID_SERVER=

echo '=== a tampered tarball is refused ==='
DIRECTORY_TAMPER="$DIRECTORY_TEST/tamper"
mkdir -p "$DIRECTORY_TAMPER"
cp "$FILE_TARBALL" "$DIRECTORY_TAMPER/"
cp "$DIRECTORY_RELEASE/SHA256SUMS" "$DIRECTORY_TAMPER/"
printf 'x' >> "$DIRECTORY_TAMPER/$(basename "$FILE_TARBALL")"
if PREFIX="$DIRECTORY_TEST/prefix-tamper" TARBALL="$DIRECTORY_TAMPER/$(basename "$FILE_TARBALL")" \
        sh "$REPOSITORY_ROOT/scripts/install.sh" >/dev/null 2>&1; then
    fail 'a tampered tarball was installed'
fi

echo '=== a tarball without a checksum is refused, unless SKIP_VERIFY is set ==='
DIRECTORY_NOSUM="$DIRECTORY_TEST/nosum"
mkdir -p "$DIRECTORY_NOSUM"
cp "$FILE_TARBALL" "$DIRECTORY_NOSUM/"
if PREFIX="$DIRECTORY_TEST/prefix-nosum" TARBALL="$DIRECTORY_NOSUM/$(basename "$FILE_TARBALL")" \
        sh "$REPOSITORY_ROOT/scripts/install.sh" >/dev/null 2>&1; then
    fail 'an unverifiable tarball was installed'
fi
PREFIX="$DIRECTORY_TEST/prefix-skip" TARBALL="$DIRECTORY_NOSUM/$(basename "$FILE_TARBALL")" SKIP_VERIFY=1 \
    sh "$REPOSITORY_ROOT/scripts/install.sh" >/dev/null \
    || fail 'SKIP_VERIFY did not permit the install'
[ -x "$DIRECTORY_TEST/prefix-skip/bin/demo" ] || fail 'the SKIP_VERIFY install produced no program'

echo '11-release-install: ok'
exit 0

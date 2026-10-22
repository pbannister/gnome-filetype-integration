#!/bin/sh
#
# install.sh: install the products of a release, verifying the download.
#
#   RELEASE_URL=https://... sh scripts/install.sh
#   TARBALL=dataflow.out/release/<project>-linux-<arch>.tar.gz sh scripts/install.sh
#
# The tarball is checked against the release's SHA256SUMS before anything is
# installed, and the install refuses when verification is impossible. Nothing is
# registered with the system: making the tools defaults stays a deliberate step
# this script prints rather than performs.
#
# Environment:
#   PREFIX         where to install (default: $HOME/.local)
#   RELEASE_URL    base URL holding the tarball and SHA256SUMS
#   TARBALL        install this local tarball instead of fetching
#   REPOSITORY     owner/repo, for the default GitHub release URL
#   VERSION        a release tag, or "latest" (default) for the GitHub URL
#   PROJECT_NAME, ARCHITECTURE   override the asset-name pieces
#   SKIP_VERIFY    set to 1 to install although SHA256SUMS is unavailable
#
# A project that publishes copies this script and sets REPOSITORY (or
# PROJECT_NAME) for itself.
#
# This script is POSIX sh on purpose: it may be piped into any shell.
#
# See prompts/capabilities/04-release-and-publishing.md.
set -eu

PREFIX=${PREFIX:-$HOME/.local}
SKIP_VERIFY=${SKIP_VERIFY:-0}
ARCHITECTURE=${ARCHITECTURE:-$(uname -m)}

case "$ARCHITECTURE" in
    x86_64 | amd64)
        ARCHITECTURE=x86_64
        ;;
    aarch64 | arm64)
        ARCHITECTURE=aarch64
        ;;
    *)
        echo "install: no build is published for machine $(uname -m)" >&2
        exit 1
        ;;
esac

fail() {
    echo "install: $1" >&2
    exit 1
}

fetch() { # <url> <destination>
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$1" -o "$2"
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$2" "$1"
    else
        fail 'neither curl nor wget is available'
    fi
}

digest_of() { # <file>
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | cut -d' ' -f1
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | cut -d' ' -f1
    else
        fail 'no sha256 tool is available'
    fi
}

install_file() { # <source> <destination>
    # Copy to a temporary name and rename it over the destination: writing in
    # place fails with "Text file busy" while the program is running, and a
    # rename leaves any running copy with the file it started from.
    file_temporary="$2.installing.$$"
    cp "$1" "$file_temporary"
    chmod 755 "$file_temporary"
    mv -f "$file_temporary" "$2"
}

DIRECTORY_TEMP=
DIRECTORY_STAGE=
cleanup() {
    if [ -n "$DIRECTORY_STAGE" ]; then
        rm -rf "$DIRECTORY_STAGE"
    fi
    if [ -n "$DIRECTORY_TEMP" ]; then
        rm -rf "$DIRECTORY_TEMP"
    fi
    return 0
}
trap cleanup EXIT HUP INT TERM

if [ -n "${TARBALL:-}" ]; then
    FILE_TARBALL=$TARBALL
    [ -f "$FILE_TARBALL" ] || fail "no such tarball: $FILE_TARBALL"
    FILE_SUMS="$(dirname "$FILE_TARBALL")/SHA256SUMS"
else
    BASE_URL=${RELEASE_URL:-}
    if [ -z "$BASE_URL" ] && [ -n "${REPOSITORY:-}" ]; then
        BASE_URL="https://github.com/$REPOSITORY/releases/${VERSION:-latest}/download"
    fi
    [ -n "$BASE_URL" ] || fail 'set TARBALL or RELEASE_URL (or REPOSITORY)'
    NAME_PROJECT=${PROJECT_NAME:-${REPOSITORY##*/}}
    [ -n "$NAME_PROJECT" ] || fail 'set PROJECT_NAME (or REPOSITORY) for the asset name'
    DIRECTORY_TEMP=$(mktemp -d)
    FILE_TARBALL="$DIRECTORY_TEMP/$NAME_PROJECT-linux-$ARCHITECTURE.tar.gz"
    FILE_SUMS="$DIRECTORY_TEMP/SHA256SUMS"
    fetch "$BASE_URL/$(basename "$FILE_TARBALL")" "$FILE_TARBALL" \
        || fail "could not fetch the tarball from $BASE_URL"
    fetch "$BASE_URL/SHA256SUMS" "$FILE_SUMS" || rm -f "$FILE_SUMS"
fi

if [ ! -f "$FILE_SUMS" ]; then
    if [ "$SKIP_VERIFY" = 1 ]; then
        echo 'install: WARNING: SHA256SUMS is unavailable; installing without verification' >&2
    else
        fail 'SHA256SUMS could not be fetched, so the download cannot be checked; set SKIP_VERIFY=1 to install anyway'
    fi
fi

if [ -f "$FILE_SUMS" ]; then
    expected_digest=$(awk -v name="$(basename "$FILE_TARBALL")" '$2 == name { print $1 }' "$FILE_SUMS")
    [ -n "$expected_digest" ] || fail "SHA256SUMS does not cover $(basename "$FILE_TARBALL")"
    actual_digest=$(digest_of "$FILE_TARBALL")
    [ "$expected_digest" = "$actual_digest" ] \
        || fail "the download does not match SHA256SUMS: expected $expected_digest but got $actual_digest"
fi

DIRECTORY_STAGE=$(mktemp -d)
tar -xzf "$FILE_TARBALL" -C "$DIRECTORY_STAGE"
[ -d "$DIRECTORY_STAGE/bin" ] || fail 'the tarball has no bin/ directory'

mkdir -p "$PREFIX/bin"
count_programs=0
for file_source in "$DIRECTORY_STAGE"/bin/*; do
    [ -f "$file_source" ] || continue
    install_file "$file_source" "$PREFIX/bin/$(basename "$file_source")"
    count_programs=$((count_programs + 1))
done
[ "$count_programs" -gt 0 ] || fail 'the tarball has no programs under bin/'

if [ -d "$DIRECTORY_STAGE/share" ]; then
    mkdir -p "$PREFIX/share"
    cp -R "$DIRECTORY_STAGE/share/." "$PREFIX/share/"
fi

echo "install: installed $count_programs program(s) into $PREFIX/bin"
echo "install: add $PREFIX/bin to PATH if it is not already there"
echo 'install: system integration is a deliberate step; see the release notes'
exit 0

#!/bin/sh
#
# install.sh: install the products of gnome-filetype-integration from a GitHub
# release.
#
#   curl -fsSL https://raw.githubusercontent.com/pbannister/gnome-filetype-integration/master/scripts/install.sh | sh
#
# It fetches the release tarball for this machine, checks it against the
# release's SHA256SUMS, and installs into $PREFIX (default $HOME/.local).  Where
# no prebuilt build exists for this machine it builds from the source archive
# instead.  It then registers the Discover Applications… handler, which writes
# only under the user's XDG directories and never needs root; that step rewrites
# the user's MIME defaults and records what they were, so it can be declined
# with FILETYPE_INTEGRATION_NO_HANDLER=1 and reversed with
# "filetype handler uninstall".
#
# Environment:
#   PREFIX                              where to install (default $HOME/.local)
#   VERSION                             a release tag, or "latest" (default)
#   REPOSITORY                          owner/repo to fetch from
#   FILETYPE_INTEGRATION_RELEASE_URL    base URL to fetch assets from, instead of GitHub
#   FILETYPE_INTEGRATION_TARBALL        install from this local tarball instead
#   FILETYPE_INTEGRATION_SKIP_VERIFY=1  install although SHA256SUMS is missing
#   FILETYPE_INTEGRATION_NO_BUILD=1     do not fall back to building from source
#   FILETYPE_INTEGRATION_NO_HANDLER=1   install the tools, register no handler
#   PROJECT_NAME                        asset-name piece (default gnome-filetype-integration)
#
# The RELEASE_URL, TARBALL, and SKIP_VERIFY names are accepted as aliases of the
# project-specific variables above, for the shared packaging test.
#
# This script is POSIX sh on purpose: it may be piped into any shell.
#
# See prompts/capabilities/04-release-and-publishing.md.
set -eu

REPOSITORY=${REPOSITORY:-pbannister/gnome-filetype-integration}
PREFIX=${PREFIX:-$HOME/.local}
VERSION=${VERSION:-latest}
PROGRAM_NAME=${PROJECT_NAME:-${PROGRAM_NAME:-gnome-filetype-integration}}
FILE_TARBALL_LOCAL=${FILETYPE_INTEGRATION_TARBALL:-${TARBALL:-}}
BASE_URL=${FILETYPE_INTEGRATION_RELEASE_URL:-${RELEASE_URL:-}}
SKIP_VERIFY=${FILETYPE_INTEGRATION_SKIP_VERIFY:-${SKIP_VERIFY:-0}}
NO_BUILD=${FILETYPE_INTEGRATION_NO_BUILD:-0}
NO_HANDLER=${FILETYPE_INTEGRATION_NO_HANDLER:-0}

say() {
    echo "install: $1"
}

fail() {
    echo "install: $1" >&2
    exit 1
}

have() {
    command -v "$1" > /dev/null 2>&1
}

# ---------------------------------------------------------------------------
# Platform

machine=$(uname -s -m 2>/dev/null || echo unknown)
case "$machine" in
    Linux\ x86_64 | Linux\ amd64)
        ARCHITECTURE=x86_64
        ;;
    Linux\ aarch64 | Linux\ arm64)
        ARCHITECTURE=aarch64
        ;;
    *)
        fail "no build is published for '$machine'; this project targets Linux on x86_64 and aarch64"
        ;;
esac
ASSET="$PROGRAM_NAME-linux-$ARCHITECTURE.tar.gz"

# ---------------------------------------------------------------------------
# Tools

if have curl; then
    fetch() { # <url> <destination>
        curl -fsSL --connect-timeout 20 --max-time 600 -o "$2" "$1"
    }
elif have wget; then
    fetch() { # <url> <destination>
        wget -q -T 20 -O "$2" "$1"
    }
else
    fail "curl or wget is needed to download anything"
fi

sha256_of() { # <file>
    if have sha256sum; then
        sha256sum "$1" | awk '{print $1}'
    elif have shasum; then
        shasum -a 256 "$1" | awk '{print $1}'
    else
        echo ""
    fi
}

if [ -z "$BASE_URL" ]; then
    if [ "latest" = "$VERSION" ]; then
        BASE_URL="https://github.com/$REPOSITORY/releases/latest/download"
    else
        BASE_URL="https://github.com/$REPOSITORY/releases/download/$VERSION"
    fi
fi

DIRECTORY_WORK=$(mktemp -d "${TMPDIR:-/tmp}/$PROGRAM_NAME-install.XXXXXX")
cleanup() {
    rm -rf "$DIRECTORY_WORK"
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Fetch and verify

verify_tarball() { # <tarball> <sums-file>
    file_tarball=$1
    file_sums=$2
    expected=$(awk -v name="$(basename "$file_tarball")" '$2 == name { print $1 }' "$file_sums")
    if [ -z "$expected" ]; then
        # A sums file made with a bare name and one made with a path both work.
        expected=$(awk -v name="$(basename "$file_tarball")" 'index($2, name) > 0 { print $1 }' \
            "$file_sums" | head -1)
    fi
    if [ -z "$expected" ]; then
        fail "$(basename "$file_sums") has no digest for $(basename "$file_tarball")"
    fi
    actual=$(sha256_of "$file_tarball")
    if [ -z "$actual" ]; then
        say "no sha256sum tool is available, so the digest could not be checked"
        return 0
    fi
    if [ "$expected" != "$actual" ]; then
        fail "the download does not match SHA256SUMS: expected $expected but got $actual"
    fi
    say "the download matches its published digest"
}

install_tarball() { # <tarball>
    file_tarball=$1
    mkdir -p "$PREFIX"
    # The tarball holds bin/, lib/, and share/, which is the layout $PREFIX is
    # meant to have; extracting it there is the install.
    tar --extract --file "$file_tarball" --directory "$PREFIX" --no-same-owner
    chmod 755 "$PREFIX/bin"/* 2>/dev/null || true
    say "installed into $PREFIX"
}

# ---------------------------------------------------------------------------
# Build from source, when no prebuilt build matches this machine

build_from_source() {
    for tool_name in python3 tar; do
        if ! have "$tool_name"; then
            fail "no prebuilt build for linux-$ARCHITECTURE, and building needs $tool_name; install it and try again, or set FILETYPE_INTEGRATION_RELEASE_URL to a mirror"
        fi
    done
    if [ "latest" = "$VERSION" ]; then
        source_url="https://github.com/$REPOSITORY/archive/refs/heads/master.tar.gz"
    else
        source_url="https://github.com/$REPOSITORY/archive/refs/tags/$VERSION.tar.gz"
    fi
    say "no prebuilt build for linux-$ARCHITECTURE: building from $source_url"
    fetch "$source_url" "$DIRECTORY_WORK/source.tar.gz" \
        || fail "could not download the source archive"
    tar --extract --file "$DIRECTORY_WORK/source.tar.gz" --directory "$DIRECTORY_WORK"
    DIRECTORY_SOURCE=$(find "$DIRECTORY_WORK" -maxdepth 1 -type d -name "$PROGRAM_NAME-*" | head -1)
    if [ -z "$DIRECTORY_SOURCE" ]; then
        fail "the source archive is not shaped as expected"
    fi
    say "building; this needs python3"
    (
        cd "$DIRECTORY_SOURCE"
        sh scripts/program-build.sh
        # Register the handler once, below, after every install path has run.
        FILETYPE_INTEGRATION_NO_HANDLER=1 PREFIX="$PREFIX" sh scripts/program-install.sh
    ) || fail "the build failed"
}

# ---------------------------------------------------------------------------
# Go

if [ -n "$FILE_TARBALL_LOCAL" ]; then
    if [ ! -f "$FILE_TARBALL_LOCAL" ]; then
        fail "$FILE_TARBALL_LOCAL is not there"
    fi
    say "installing from $FILE_TARBALL_LOCAL"
    FILE_SUMS_LOCAL="$(dirname "$FILE_TARBALL_LOCAL")/SHA256SUMS"
    if [ -f "$FILE_SUMS_LOCAL" ]; then
        verify_tarball "$FILE_TARBALL_LOCAL" "$FILE_SUMS_LOCAL"
    elif [ "1" = "$SKIP_VERIFY" ]; then
        say "SHA256SUMS is unavailable, and verification was skipped on request"
    else
        fail "SHA256SUMS is unavailable next to $FILE_TARBALL_LOCAL, so the tarball cannot be checked; set FILETYPE_INTEGRATION_SKIP_VERIFY=1 to install anyway"
    fi
    install_tarball "$FILE_TARBALL_LOCAL"
else
    FILE_TARBALL="$DIRECTORY_WORK/$ASSET"
    if fetch "$BASE_URL/$ASSET" "$FILE_TARBALL" 2>/dev/null; then
        if fetch "$BASE_URL/SHA256SUMS" "$DIRECTORY_WORK/SHA256SUMS" 2>/dev/null; then
            verify_tarball "$FILE_TARBALL" "$DIRECTORY_WORK/SHA256SUMS"
        elif [ "1" = "$SKIP_VERIFY" ]; then
            say "SHA256SUMS could not be fetched, and verification was skipped on request"
        else
            fail "SHA256SUMS could not be fetched, so the download cannot be checked; set FILETYPE_INTEGRATION_SKIP_VERIFY=1 to install anyway"
        fi
        install_tarball "$FILE_TARBALL"
    elif [ "1" = "$NO_BUILD" ]; then
        fail "there is no $ASSET in $VERSION; nothing was installed"
    else
        build_from_source
    fi
fi

# ---------------------------------------------------------------------------
# Register the handler
#
# The handler is what makes double-clicking a file open the chooser, and what
# gives the types their icon.  It rewrites the user's MIME defaults and records
# the previous ones, which is why the step stays visible -- but a user who has
# just installed these tools has asked for the tool, so it runs here, says what
# it did, and says how to undo it.  A failure is reported rather than fatal: the
# tools are installed either way, and the command to finish the job is printed.

if [ "1" = "$NO_HANDLER" ]; then
    say "the desktop handler was not registered, on request (FILETYPE_INTEGRATION_NO_HANDLER=1)"
elif [ -x "$PREFIX/bin/filetype" ]; then
    if FILETYPE_EXECUTABLE="$PREFIX/bin/filetype" \
            "$PREFIX/bin/filetype" handler install > "$DIRECTORY_WORK/handler.txt" 2>&1; then
        say "the File Type Chooser is now installed as the handler for the known types"
    else
        say "the desktop handler could not be registered; the tool said:"
        cat "$DIRECTORY_WORK/handler.txt" 2>/dev/null || true
        say "run it yourself with: $PREFIX/bin/filetype handler install"
    fi
fi

# ---------------------------------------------------------------------------
# Report

VERSION_INSTALLED="unknown"
if [ -f "$PREFIX/VERSION" ]; then
    VERSION_INSTALLED=$(cat "$PREFIX/VERSION")
fi

echo
say "installed version $VERSION_INSTALLED into $PREFIX"
if [ -x "$PREFIX/bin/filetype" ]; then
    echo "  $PREFIX/bin/filetype"
fi
if [ -d "$PREFIX/lib/gnome-filetype-integration" ]; then
    echo "  $PREFIX/lib/gnome-filetype-integration"
fi
if [ -f "$PREFIX/share/icons/hicolor/scalable/apps/filetype-chooser.svg" ]; then
    echo "  $PREFIX/share/icons/hicolor/scalable/apps/filetype-chooser.svg"
fi

case ":$PATH:" in
    *":$PREFIX/bin:"*)
        ;;
    *)
        echo
        say "$PREFIX/bin is not on your PATH; add it, for example:"
        echo "  export PATH=\"$PREFIX/bin:\$PATH\""
        ;;
esac

echo
if [ "1" = "$NO_HANDLER" ]; then
    say "to make the File Type Chooser the handler, which this run skipped:"
    echo "  $PREFIX/bin/filetype handler install"
else
    say "to stop the File Type Chooser being the handler, and restore the"
    say "handler that was there before:"
    echo "  $PREFIX/bin/filetype handler uninstall"
fi
say "to identify a file:"
echo "  $PREFIX/bin/filetype identify ~/Downloads/file.png"

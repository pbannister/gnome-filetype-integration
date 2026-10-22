#!/bin/sh
#
# program-install.sh: install the staged program under PREFIX.
#
# Usage: program-install.sh
#
# Environment:
#   PREFIX                          install root (default: $HOME/.local)
#   DESTDIR                         staging root for packaging
#   FILETYPE_INTEGRATION_NO_HANDLER set to 1 to install the tools without
#                                   registering the desktop handler
#
# Unlike the release installer, a make install that cannot register the
# handler exits nonzero: a scripted install must not report success with the
# association missing.  Registration itself writes only under
# $XDG_DATA_HOME, $XDG_CONFIG_HOME, and the temporary directory, never root.
set -eu

DIRECTORY_SCRIPT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$DIRECTORY_SCRIPT/.." && pwd)
PREFIX=${PREFIX:-$HOME/.local}
DESTDIR=${DESTDIR:-}
DIRECTORY_PROGRAM="$REPOSITORY_ROOT/dataflow.out/build/program"

if [ ! -x "$DIRECTORY_PROGRAM/bin/filetype" ]; then
    echo "program-install: the program is not built; run scripts/program-build.sh first" >&2
    exit 1
fi

DIRECTORY_BIN="$DESTDIR$PREFIX/bin"
DIRECTORY_LIB="$DESTDIR$PREFIX/lib/gnome-filetype-integration"
DIRECTORY_ICON="$DESTDIR$PREFIX/share/icons/hicolor/scalable/apps"

mkdir -p "$DIRECTORY_BIN" "$DIRECTORY_LIB" "$DIRECTORY_ICON"
rm -rf "$DIRECTORY_LIB"
cp -R "$DIRECTORY_PROGRAM/lib/gnome-filetype-integration" "$DIRECTORY_LIB"
cp "$DIRECTORY_PROGRAM/bin/filetype" "$DIRECTORY_BIN/filetype"
chmod 755 "$DIRECTORY_BIN/filetype"
cp "$REPOSITORY_ROOT/sources/filetype_integration/data/filetype-chooser.svg" "$DIRECTORY_ICON/filetype-chooser.svg" 2>/dev/null || true
echo "program-install: installed filetype into $DIRECTORY_BIN"

if [ "${FILETYPE_INTEGRATION_NO_HANDLER:-0}" = 1 ]; then
    echo "program-install: FILETYPE_INTEGRATION_NO_HANDLER=1; the desktop handler was not registered"
    echo "program-install: run '$PREFIX/bin/filetype handler install' when you want it"
    exit 0
fi

# The entry must point at this install, even when PREFIX/bin is not on PATH.
FILETYPE_EXECUTABLE="$PREFIX/bin/filetype" "$PREFIX/bin/filetype" handler install
echo "program-install: registered the File Type Chooser"

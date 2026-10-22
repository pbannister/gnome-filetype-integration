#!/bin/sh
#
# Test that the GTK4 chooser builds its window, for a handled and an unhandled
# file, under a virtual X server.
#
# Tier: tool-gated (xvfb-run and GTK4).
set -eu

DIRECTORY_SCRIPT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$DIRECTORY_SCRIPT/.." && pwd)
. "$DIRECTORY_SCRIPT/lib/filetype_env.sh"
. "$DIRECTORY_SCRIPT/lib/test_helpers.sh"
skip_unless_tool python3
skip_unless_tool xvfb-run

python3 - <<'PY' || { echo 'SKIP: missing tool: gtk4'; exit 0; }
import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk
assert Gtk.get_major_version() == 4
PY

filetype_sandbox
trap filetype_cleanup EXIT HUP INT TERM

fail() {
    echo "80-gtk-chooser: $1" >&2
    exit 1
}

run_chooser() { # <file>
    output=$(xvfb-run -a env GDK_BACKEND=x11 "$FILETYPE" choose --self-test "$1" 2>&1) \
        || fail "the chooser failed for $1"
    printf '%s' "$output" | grep -q 'chooser window built' \
        || fail "the chooser window was not built for $1"
}

run_chooser "$FIXTURES/sample.png"
run_chooser "$FIXTURES/sample.custom"
run_chooser "$FIXTURES/sample-renamed.txt"

# The chooser is the handler entry point too.
output=$(xvfb-run -a env GDK_BACKEND=x11 "$FILETYPE" handle --self-test "$FIXTURES/sample.txt" 2>&1) \
    || fail 'handle failed'
printf '%s' "$output" | grep -q 'chooser window built' || fail 'handle did not build the window'

echo '80-gtk-chooser: ok'
exit 0

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
run_chooser "$FIXTURES/sample.gguf"
run_chooser "$FIXTURES/sample.pkpass"

# The chooser is the handler entry point too.
output=$(xvfb-run -a env GDK_BACKEND=x11 "$FILETYPE" handle --self-test "$FIXTURES/sample.txt" 2>&1) \
    || fail 'handle failed'
printf '%s' "$output" | grep -q 'chooser window built' || fail 'handle did not build the window'

# Two chooser processes must not see each other as the same GApplication
# instance.  If they do, the second remote-activates the first and one window
# is created twice or the second process exits without building a window.
FILE_ONE="$DIRECTORY_TEST/parallel-one.log"
FILE_TWO="$DIRECTORY_TEST/parallel-two.log"
xvfb-run -a -n 91 env GDK_BACKEND=x11 "$FILETYPE" choose --self-test "$FIXTURES/sample.png" >"$FILE_ONE" 2>&1 &
PID_ONE=$!
xvfb-run -a -n 92 env GDK_BACKEND=x11 "$FILETYPE" choose --self-test "$FIXTURES/sample.custom" >"$FILE_TWO" 2>&1 &
PID_TWO=$!
status_one=0
wait "$PID_ONE" || status_one=$?
status_two=0
wait "$PID_TWO" || status_two=$?
[ "$status_one" -eq 0 ] || fail 'the first parallel chooser failed'
[ "$status_two" -eq 0 ] || fail 'the second parallel chooser failed'
grep -q 'chooser window built' "$FILE_ONE" || fail 'the first parallel chooser built no window'
grep -q 'chooser window built' "$FILE_TWO" || fail 'the second parallel chooser built no window'

echo '80-gtk-chooser: ok'
exit 0

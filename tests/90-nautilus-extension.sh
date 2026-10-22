#!/bin/sh
#
# Test the optional Nautilus extension: it compiles, it is a menu provider, it
# is installed only when the bindings exist, and it is removed again.
#
# Tier: portable for the source checks; the install step is tool-gated on the
# Nautilus Python bindings.
set -eu

DIRECTORY_SCRIPT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$DIRECTORY_SCRIPT/.." && pwd)
. "$DIRECTORY_SCRIPT/lib/filetype_env.sh"
. "$DIRECTORY_SCRIPT/lib/test_helpers.sh"
skip_unless_tool python3

filetype_sandbox
trap filetype_cleanup EXIT HUP INT TERM

SOURCE_EXTENSION="$REPOSITORY_ROOT/sources/filetype_integration/data/filetype_nautilus.py"
[ -f "$SOURCE_EXTENSION" ] || { echo 'SKIP: missing Nautilus extension source'; exit 0; }

# 1. The extension parses.
python3 - "$SOURCE_EXTENSION" "$DIRECTORY_TEST" <<'PY' || exit 1
import py_compile
import sys
py_compile.compile(sys.argv[1], cfile=sys.argv[2] + "/filetype_nautilus.pyc", doraise=True)
PY

# 2. It declares the menu contract and the two actions.
grep -q 'Nautilus.MenuProvider' "$SOURCE_EXTENSION" || {
    echo '90-nautilus-extension: no menu provider' >&2
    exit 1
}
grep -q 'Choose Application' "$SOURCE_EXTENSION" || {
    echo '90-nautilus-extension: no choose action' >&2
    exit 1
}
grep -q 'Inspect File Type' "$SOURCE_EXTENSION" || {
    echo '90-nautilus-extension: no inspect action' >&2
    exit 1
}
grep -q 'get_file_items' "$SOURCE_EXTENSION" || {
    echo '90-nautilus-extension: no get_file_items' >&2
    exit 1
}

# 3. A --no-nautilus install never writes the extension.
"$FILETYPE" handler install --no-nautilus >/dev/null || exit 1
if [ -e "$XDG_DATA_HOME/nautilus-python/extensions/filetype_nautilus.py" ]; then
    echo '90-nautilus-extension: --no-nautilus still wrote the extension' >&2
    exit 1
fi

# 4. When the bindings are available, a normal install writes it and uninstall
#    removes it.  Without them, the tool reports the package to install.
if python3 -c "import gi; gi.require_version('Nautilus', '4.0'); from gi.repository import Nautilus" 2>/dev/null; then
    "$FILETYPE" handler install >/dev/null || exit 1
    [ -f "$XDG_DATA_HOME/nautilus-python/extensions/filetype_nautilus.py" ] || {
        echo '90-nautilus-extension: the bindings exist but the extension was not installed' >&2
        exit 1
    }
    "$FILETYPE" handler uninstall >/dev/null || exit 1
    [ ! -e "$XDG_DATA_HOME/nautilus-python/extensions/filetype_nautilus.py" ] || {
        echo '90-nautilus-extension: uninstall left the extension' >&2
        exit 1
    }
else
    "$FILETYPE" handler uninstall >/dev/null 2>&1 || true
    echo '90-nautilus-extension: ok (bindings absent; install path skipped)'
    exit 0
fi

echo '90-nautilus-extension: ok'
exit 0

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

# 4. Detect the typelibs independently of the tool's own detector, so the
#    check verifies the install decision rather than repeating it.
NAUTILUS_VERSION=$(python3 - <<'PY'
import gi
for version in ("4.1", "4.0"):
    try:
        gi.require_version("Nautilus", version)
        from gi.repository import Nautilus
    except (ValueError, ImportError):
        continue
    print(version)
    break
PY
)

if [ -n "$NAUTILUS_VERSION" ]; then
    "$FILETYPE" handler install >/dev/null || exit 1
    FILE_EXTENSION_INSTALLED="$XDG_DATA_HOME/nautilus-python/extensions/filetype_nautilus.py"
    [ -f "$FILE_EXTENSION_INSTALLED" ] || {
        echo '90-nautilus-extension: the bindings exist but the extension was not installed' >&2
        exit 1
    }
    cmp -s "$FILE_EXTENSION_INSTALLED" "$SOURCE_EXTENSION" || {
        echo '90-nautilus-extension: the installed copy differs from the source' >&2
        exit 1
    }

    # 5. The installed extension builds the two menu items and launches the
    #    right commands.  A recorder replaces the launcher, so no process
    #    starts and no real file is touched.
    python3 - "$FILE_EXTENSION_INSTALLED" "$NAUTILUS_VERSION" "$FILETYPE" <<'PY' || exit 1
import importlib.util
import os
import sys

import gi
gi.require_version("Nautilus", sys.argv[2])
from gi.repository import Nautilus

os.environ["PATH"] = os.path.dirname(sys.argv[3]) + os.pathsep + os.environ.get("PATH", "")

spec = importlib.util.spec_from_file_location("filetype_nautilus_under_test", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
extension = module.FiletypeExtension()
target = "/tmp/sample file.srt"

class Location:
    def get_path(self):
        return target

class FileInfo:
    def get_location(self):
        return Location()

    def get_uri(self):
        return "file://" + target

items = extension.get_file_items([FileInfo()])
assert len(items) == 2, items
assert items[0].get_property("name") == "FiletypeExtension::choose"
assert items[1].get_property("name") == "FiletypeExtension::inspect"
assert items[0].get_property("label") == "Choose Application…"
assert items[1].get_property("label") == "Inspect File Type"
assert extension.get_file_items([]) == []
assert extension.get_background_items([]) == []

calls = []
module._launch = lambda arguments: calls.append(list(arguments))
items[0].emit("activate")
items[1].emit("activate")
assert calls == [
    [sys.argv[3], "choose", target],
    [sys.argv[3], "identify", "--apps", target],
], calls
PY

    "$FILETYPE" handler uninstall >/dev/null || exit 1
    [ ! -e "$FILE_EXTENSION_INSTALLED" ] || {
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

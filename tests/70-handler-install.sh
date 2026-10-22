#!/bin/sh
#
# Test handler install, status, idempotency, uninstall, restoration, and the
# refusal paths, entirely inside the sandboxed XDG tree.
#
# Tier: portable (python3 and the staged program).
set -eu

DIRECTORY_SCRIPT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$DIRECTORY_SCRIPT/.." && pwd)
. "$DIRECTORY_SCRIPT/lib/filetype_env.sh"
. "$DIRECTORY_SCRIPT/lib/test_helpers.sh"
skip_unless_tool python3

filetype_sandbox
trap filetype_cleanup EXIT HUP INT TERM

fail() {
    echo "70-handler-install: $1" >&2
    exit 1
}

# 1. A dry run changes nothing but reports the plan.
before=$(find "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" -type f | wc -l)
"$FILETYPE" handler install --dry-run --no-nautilus --json > "$DIRECTORY_TEST/dry.json" \
    || fail 'dry-run install failed'
after=$(find "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" -type f | wc -l)
[ "$before" = "$after" ] || fail 'the dry run wrote files'
python3 - "$DIRECTORY_TEST/dry.json" <<'PY' || fail 'the dry-run document is wrong'
import json, sys
r = json.load(open(sys.argv[1], encoding="utf-8"))["result"]
assert r["ok"] is True and r["dry_run"] is True
assert r["handler_mime_types"] >= 10, r
assert r["defaults_set"] >= 1, r
PY

# 2. Install for real.
"$FILETYPE" handler install --no-nautilus --json > "$DIRECTORY_TEST/install.json" \
    || fail 'install failed'
python3 - "$DIRECTORY_TEST/install.json" "$DIRECTORY_TEST" <<'PY' || fail 'the install document is wrong'
import json, sys
r = json.load(open(sys.argv[1], encoding="utf-8"))["result"]
assert r["ok"] is True and r["dry_run"] is False
assert r["defaults_set"] >= 1, r
assert r["handler_mime_types"] >= 10, r
assert r["desktop_entry"].endswith("filetype-handler.desktop")
PY

FILE_DESKTOP="$XDG_DATA_HOME/applications/filetype-handler.desktop"
FILE_MANIFEST="$XDG_DATA_HOME/gnome-filetype-integration/handler-manifest.json"
FILE_MIMEAPPS="$XDG_CONFIG_HOME/mimeapps.list"
[ -f "$FILE_DESKTOP" ] || fail 'the desktop entry was not written'
[ -f "$FILE_MANIFEST" ] || fail 'the manifest was not written'
[ -f "$XDG_DATA_HOME/icons/hicolor/scalable/apps/filetype-chooser.svg" ] || fail 'the icon was not written'

grep -q '^Name=File Type Chooser$' "$FILE_DESKTOP" || fail 'the entry has no name'
grep -q '^Exec=.* handle %f$' "$FILE_DESKTOP" || fail 'the entry does not call handle'
grep -q 'MimeType=.*text/plain' "$FILE_DESKTOP" || fail 'the entry does not list text/plain'
grep -q 'MimeType=.*application/pdf' "$FILE_DESKTOP" || fail 'the entry does not list application/pdf'
grep -q 'MimeType=.*inode/directory' "$FILE_DESKTOP" && fail 'the entry claims directories'

python3 - "$FILE_DESKTOP" "$FILE_MANIFEST" "$FILE_MIMEAPPS" <<'PY' || fail 'the installed state is wrong'
import json, sys
desktop, manifest_path, mimeapps = sys.argv[1:]
entry = open(desktop, encoding="utf-8").read()
mime_line = next(line for line in entry.splitlines() if line.startswith("MimeType="))
types = [item for item in mime_line.split("=", 1)[1].split(";") if item]
assert "application/x-custom-format" in types, types
assert "inode/directory" not in types, types

manifest = json.load(open(manifest_path, encoding="utf-8"))
assert manifest["schema"] == 1
assert manifest["previous_defaults"]["image/png"] == "test-broken.desktop"
assert manifest["previous_defaults"]["application/pdf"] == ""
assert "application/pdf" in manifest["default_types"], manifest["default_types"]
assert "image/png" in manifest["default_types"], manifest["default_types"]
assert "text/plain" not in manifest["default_types"], manifest["default_types"]

text = open(mimeapps, encoding="utf-8").read()
assert "text/plain=test-editor.desktop;" in text, text
assert "image/png=filetype-handler.desktop;" in text, text
assert "application/pdf=filetype-handler.desktop;" in text, text
assert "application/x-custom-format=filetype-handler.desktop;" in text, text
PY

# 2.1 The desktop entry is valid, and GIO sees what the desktop will see.
if command -v desktop-file-validate >/dev/null 2>&1; then
    desktop-file-validate "$FILE_DESKTOP" >/dev/null 2>&1 \
        || fail 'desktop-file-validate rejected the handler entry'
fi
if command -v gio >/dev/null 2>&1; then
    gio mime text/plain > "$DIRECTORY_TEST/gio-plain.txt" 2>&1 || true
    grep -q 'Default application.*test-editor.desktop' "$DIRECTORY_TEST/gio-plain.txt" \
        || fail 'GIO no longer reports the working text/plain default'
    grep -q 'filetype-handler.desktop' "$DIRECTORY_TEST/gio-plain.txt" \
        || fail 'GIO does not list the chooser for text/plain'
    gio mime application/pdf > "$DIRECTORY_TEST/gio-pdf.txt" 2>&1 || true
    grep -q 'Default application.*filetype-handler.desktop' "$DIRECTORY_TEST/gio-pdf.txt" \
        || fail 'GIO does not report the chooser as the pdf default'
fi

# 3. Status reports the installed handler and its ownership.
"$FILETYPE" handler status --json > "$DIRECTORY_TEST/status.json" \
    || fail 'status failed after install'
python3 - "$DIRECTORY_TEST/status.json" <<'PY' || fail 'the status document is wrong'
import json, sys
s = json.load(open(sys.argv[1], encoding="utf-8"))["handler"]
assert s["installed"] is True
assert s["desktop_entry_present"] is True
assert s["icon_present"] is True
assert s["defaults_owned"] >= 3, s
PY

# 4. A second install is idempotent and does not duplicate keys.
"$FILETYPE" handler install --no-nautilus --json > "$DIRECTORY_TEST/install2.json" \
    || fail 'the second install failed'
python3 - "$DIRECTORY_TEST/install2.json" "$FILE_MIMEAPPS" <<'PY' || fail 'the second install changed defaults'
import json, sys
r = json.load(open(sys.argv[1], encoding="utf-8"))["result"]
assert r["defaults_set"] == 0, r
text = open(sys.argv[2], encoding="utf-8").read()
assert text.count("application/pdf=filetype-handler.desktop;") == 1
PY

# 5. A choice the user makes after installing survives the uninstall.
python3 - "$FILE_MIMEAPPS" <<'PY'
import sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
text = text.replace("application/x-custom-format=filetype-handler.desktop;",
                    "application/x-custom-format=test-editor.desktop;")
open(path, "w", encoding="utf-8").write(text)
PY
"$FILETYPE" handler uninstall --json > "$DIRECTORY_TEST/uninstall.json" \
    || fail 'uninstall failed'
python3 - "$DIRECTORY_TEST/uninstall.json" "$FILE_MIMEAPPS" <<'PY' || fail 'the uninstall did not restore the desktop'
import json, sys
r = json.load(open(sys.argv[1], encoding="utf-8"))["result"]
assert r["ok"] is True
assert r["restored_defaults"] >= 1, r
assert r["kept_user_defaults"] >= 1, r
text = open(sys.argv[2], encoding="utf-8").read()
assert "application/x-custom-format=test-editor.desktop;" in text, text
assert "image/png=test-broken.desktop;" in text, text
assert "application/pdf=" not in text, text
assert "filetype-handler.desktop" not in text, text
PY

for path in "$FILE_DESKTOP" "$FILE_MANIFEST" \
            "$XDG_DATA_HOME/icons/hicolor/scalable/apps/filetype-chooser.svg"; do
    [ ! -e "$path" ] || fail "uninstall left $path behind"
done

# 6. A second uninstall refuses rather than guessing.
set +e
"$FILETYPE" handler uninstall > "$DIRECTORY_TEST/uninstall2.out" 2>&1
status=$?
set -e
[ "$status" -eq 3 ] || fail "the second uninstall exited $status, expected 3"
grep -q 'nothing to uninstall' "$DIRECTORY_TEST/uninstall2.out" \
    || fail 'the second uninstall did not explain the refusal'

# 7. --no-defaults registers the entry but changes no association.
filetype_cleanup
filetype_sandbox
cp "$REPOSITORY_ROOT/dataflow.in/mimeapps.list" "$XDG_CONFIG_HOME/mimeapps.list"
"$FILETYPE" handler install --no-defaults --no-nautilus --json > "$DIRECTORY_TEST/nodefaults.json" \
    || fail 'install --no-defaults failed'
python3 - "$DIRECTORY_TEST/nodefaults.json" "$XDG_CONFIG_HOME/mimeapps.list" <<'PY' || fail '--no-defaults changed associations'
import json, sys
r = json.load(open(sys.argv[1], encoding="utf-8"))["result"]
assert r["defaults_set"] == 0, r
text = open(sys.argv[2], encoding="utf-8").read()
assert "filetype-handler.desktop" not in text, text
PY
"$FILETYPE" handler uninstall >/dev/null || fail 'the --no-defaults install could not be removed'

echo '70-handler-install: ok'
exit 0

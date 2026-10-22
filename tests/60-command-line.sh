#!/bin/sh
#
# Test the command-line interface end to end against the sandboxed desktop.
#
# Tier: portable (python3 and the staged program; the test runner builds it).
set -eu

DIRECTORY_SCRIPT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$DIRECTORY_SCRIPT/.." && pwd)
. "$DIRECTORY_SCRIPT/lib/filetype_env.sh"
. "$DIRECTORY_SCRIPT/lib/test_helpers.sh"
skip_unless_tool python3
skip_unless_tool file

filetype_sandbox
trap filetype_cleanup EXIT HUP INT TERM

fail() {
    echo "60-command-line: $1" >&2
    exit 1
}

# 1. A JSON identification carries the stable schema and the evidence.
"$FILETYPE" identify --json "$FIXTURES/sample.png" > "$DIRECTORY_TEST/id.json" \
    || fail 'identify --json failed'
python3 - "$DIRECTORY_TEST/id.json" <<'PY' || fail 'the identification document is wrong'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
assert d["schema"] == 1
f = d["files"][0]
assert f["mime"] == "image/png"
assert f["source"] == "agreement"
assert f["applications"]["installed"]
assert f["applications"]["available"]
assert f["applications"]["default"] is None, f["applications"]["default"]
PY

# 2. The global --json flag and the subcommand flag are equivalent.
"$FILETYPE" --json identify "$FIXTURES/sample.txt" > "$DIRECTORY_TEST/global.json" \
    || fail 'global --json failed'
python3 - "$DIRECTORY_TEST/global.json" <<'PY' || fail 'global --json is not the same document'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
assert d["schema"] == 1 and d["files"][0]["mime"] == "text/plain"
PY

# 3. The installed and suggested application lists are both reported.
"$FILETYPE" apps --mime application/pdf --json > "$DIRECTORY_TEST/apps.json" \
    || fail 'apps --mime failed'
python3 - "$DIRECTORY_TEST/apps.json" <<'PY' || fail 'the applications document is wrong'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
apps = d["applications"]
names = [item["name"] for item in apps["installed"]]
assert "Test Broken Viewer" in names, names
assert apps["unhandled"] is False or apps["unhandled"] is True
assert any(item["installed"] is False for item in apps["available"])
PY

# 4. A dry run prints the command without starting it.
output=$("$FILETYPE" open --print --app "Test Editor" "$FIXTURES/sample.txt") \
    || fail 'open --print failed'
printf '%s' "$output" | grep -q '/bin/true' || fail 'the printed command is missing the executable'
printf '%s' "$output" | grep -q 'sample.txt' || fail 'the printed command is missing the file'

# 5. Without --app, the working default is used (the broken image default is
#    not selected for a text file).
output=$("$FILETYPE" open --print "$FIXTURES/sample.txt") || fail 'open --print with the default failed'
printf '%s' "$output" | grep -q 'sample.txt' || fail 'the default command is missing the file'

# 6. A catalog application that is not installed is refused with its command.
set +e
"$FILETYPE" open --print --app Inkscape "$FIXTURES/sample.png" > "$DIRECTORY_TEST/missing-app.out" 2>&1
status=$?
set -e
[ "$status" -eq 3 ] || fail "open for a missing application exited $status, expected 3"
grep -q 'not installed' "$DIRECTORY_TEST/missing-app.out" || fail 'the missing-application message is absent'
grep -q 'inkscape' "$DIRECTORY_TEST/missing-app.out" || fail 'the install hint is absent'

# 7. Scanning reports files that need help, and can fail for a script.
"$FILETYPE" scan --json "$FIXTURES" > "$DIRECTORY_TEST/scan.json" || fail 'scan --json failed'
python3 - "$DIRECTORY_TEST/scan.json" <<'PY' || fail 'the scan document is wrong'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
assert d["schema"] == 1
assert d["summary"]["files"] >= 8, d["summary"]
assert d["summary"]["unhandled"] >= 1, d["summary"]
assert any(item["path"].endswith("sample.custom") for item in d["files"])
PY

set +e
"$FILETYPE" scan --unhandled-only --fail-on-unhandled "$FIXTURES" >/dev/null 2>&1
status=$?
set -e
[ "$status" -eq 4 ] || fail "scan --fail-on-unhandled exited $status, expected 4"

# 8. Type inspection works for a compound extension and a MIME type.
"$FILETYPE" types --ext tar.gz | grep -q 'application/x-compressed-tar' \
    || fail 'types --ext did not resolve tar.gz'
"$FILETYPE" types --mime text/markdown | grep -q 'Markdown document' \
    || fail 'types --mime did not describe markdown'

# 9. The catalog commands work and validate the shipped data.
"$FILETYPE" catalog validate | grep -q 'Catalog valid' || fail 'catalog validate failed'
"$FILETYPE" catalog search gimp --json > "$DIRECTORY_TEST/search.json" || fail 'catalog search failed'
python3 - "$DIRECTORY_TEST/search.json" <<'PY' || fail 'the catalog search document is wrong'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
assert any(item["id"] == "org.gimp.GIMP" for item in d["applications"])
PY
"$FILETYPE" catalog show org.gimp.GIMP | grep -q 'Raster image editor' \
    || fail 'catalog show did not print the purpose'

# 9.1 The About history is inspectable and clearable.
"$FILETYPE" about-history --json > "$DIRECTORY_TEST/about-history.json" \
    || fail 'about-history --json failed'
python3 - "$DIRECTORY_TEST/about-history.json" <<'PYCHECK' || fail 'the About history document is wrong'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
assert d["schema"] == 1
assert isinstance(d["history"], list)
assert d["path"].endswith("about-sites.json")
PYCHECK
"$FILETYPE" about-history --clear --json > "$DIRECTORY_TEST/about-clear.json" \
    || fail 'about-history --clear failed'
python3 - "$DIRECTORY_TEST/about-clear.json" <<'PYCHECK' || fail 'the cleared About history document is wrong'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
assert d["cleared"] is True
assert d["history"] == []
PYCHECK

# 10. Doctor reports machine checks without failing on warnings.
"$FILETYPE" doctor --json > "$DIRECTORY_TEST/doctor.json" || fail 'doctor failed'
python3 - "$DIRECTORY_TEST/doctor.json" <<'PY' || fail 'the doctor document is wrong'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
assert d["checks"]
assert any(item["check"] == "MIME database" for item in d["checks"])
assert not any(item["status"] == "FAIL" for item in d["checks"])
PY

# 11. Missing files are findings, not crashes.
set +e
"$FILETYPE" identify "$DIRECTORY_TEST/missing.xyz" >/dev/null 2>&1
status=$?
set -e
[ "$status" -eq 1 ] || fail "identify on a missing file exited $status, expected 1"

# 12. Handler status is honest about a handler that is not installed.
set +e
"$FILETYPE" handler status --json > "$DIRECTORY_TEST/handler.json" 2>/dev/null
status=$?
set -e
[ "$status" -eq 3 ] || fail "handler status exited $status, expected 3"
python3 - "$DIRECTORY_TEST/handler.json" <<'PY' || fail 'the handler status document is wrong'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
assert d["handler"]["installed"] is False
PY

# 13. Version is a build fact, not an empty string.
"$FILETYPE" version | grep -q '^filetype ' || fail 'version is missing the program name'

echo '60-command-line: ok'
exit 0

#!/bin/sh
#
# Test desktop application discovery and MIME default resolution against the
# fixture desktop.  No real desktop is read.
#
# Tier: portable (python3 only).
set -eu

DIRECTORY_SCRIPT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$DIRECTORY_SCRIPT/.." && pwd)
. "$DIRECTORY_SCRIPT/lib/filetype_env.sh"
. "$DIRECTORY_SCRIPT/lib/test_helpers.sh"
skip_unless_tool python3

filetype_sandbox
trap filetype_cleanup EXIT HUP INT TERM

PYTHONPATH="$REPOSITORY_ROOT/sources${PYTHONPATH:+:$PYTHONPATH}" python3 - <<'PY'
from filetype_integration.desktop_application import (ApplicationIndex,
                                                       application_homepage,
                                                       command_for_file,
                                                       command_template,
                                                       discover_desktop_entries,
                                                       entry_is_visible,
                                                       parse_desktop_entry,
                                                       read_mime_defaults)
from filetype_integration.mime_index import TypeIndex

index = TypeIndex.load()
entries = discover_desktop_entries()
assert 5 <= len(entries) <= 8, len(entries)
assert "test-editor.desktop" in entries
assert entries["test-editor.desktop"].name == "Test Editor"
assert entries["test-editor.desktop"].mime_types == ["text/plain"]
assert entries["test-terminal-editor.desktop"].terminal is True
assert entries["test-broken.desktop"].executable_available is False
assert entries["test-editor.desktop"].executable == "/bin/true"

defaults = read_mime_defaults()
assert defaults.default_for("text/plain") == "test-editor.desktop"
assert defaults.default_for("image/png") == "test-broken.desktop"
assert defaults.sources, "the fixture mimeapps.list was not read"

applications = ApplicationIndex(index=index, entries=entries, defaults=defaults, use_gio=False)

# 1. A working default is resolved and ranked first.
plain = applications.for_mime("text/plain")
assert plain, plain
assert plain[0].desktop_id == "test-editor.desktop"
assert plain[0].match_kind == "default"
assert any(application.desktop_id == "test-terminal-editor.desktop" for application in plain)

# 2. An exact type beats an inherited one.
python = applications.for_mime("text/x-python")
assert python[0].desktop_id == "test-python-editor.desktop", python
assert any(application.desktop_id == "test-editor.desktop" for application in python)
# A Python script is a subclass of application/x-executable in shared-mime-info,
# but a debugger is not a Python handler.
assert not any(application.desktop_id == "test-debugger.desktop" for application in python), python

# 3. A broken default is visible but is not a usable handler.
broken = applications.default_for("image/png")
assert broken is not None and broken.desktop_id == "test-broken.desktop"
assert broken.executable_available is False
assert applications.default_for("application/pdf") is None
assert applications.has_any_handler("application/pdf") is False
assert applications.has_any_handler("image/png") is True
assert applications.has_any_handler("application/x-custom-format") is False

# 4. The alias resolves to the same family.
assert "application/pdf" in index.handler_family("application/x-pdf")
assert applications.for_mime("application/x-pdf"), "the alias found no handler"

# 5. Exec lines become argv templates.
assert command_template("/bin/true %f") == ["/bin/true", "{file}"]
assert command_for_file("/bin/true %U", "/tmp/a b.txt") == ["/bin/true", "/tmp/a b.txt"]
assert command_for_file("/bin/true %f %i", "/tmp/a") == ["/bin/true", "/tmp/a"]

# 6. Visibility follows NoDisplay and Hidden.
assert entry_is_visible({}) is True
assert entry_is_visible({"NoDisplay": "true"}) is False
assert entry_is_visible({"Hidden": "true"}) is False

# 7. AppStream metadata supplies a project page.
assert application_homepage(entries["test-editor.desktop"]) == "https://example.org/test-editor"
assert application_homepage(entries["test-image-viewer.desktop"]) == "https://example.org/test-image-viewer"

# 8. The parser keeps the fields this tool uses.
values = parse_desktop_entry(__import__("pathlib").Path(
    entries["test-editor.desktop"].source_path))
assert values["Name"] == "Test Editor"
assert values["MimeType"] == "text/plain;"
print("25-desktop-application: ok")
PY
exit 0

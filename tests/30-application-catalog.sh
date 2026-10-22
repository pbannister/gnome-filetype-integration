#!/bin/sh
#
# Test the curated catalog, its schema validation, its matching, and the
# ranking that puts installed applications first.
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
import json
import os
from pathlib import Path

from filetype_integration.application_catalog import (ApplicationCatalog, CatalogError,
                                                       install_commands, preferred_install,
                                                       recommend)
from filetype_integration.desktop_application import ApplicationIndex
from filetype_integration.file_identifier import identify
from filetype_integration.mime_index import TypeIndex

index = TypeIndex.load()
applications = ApplicationIndex(index=index, use_gio=False)
catalog = ApplicationCatalog.load()
stats = catalog.stats()

# 1. The catalog is large enough to be useful and every entry is complete.
assert 150 <= stats["applications"] <= 400, stats
assert 150 <= stats["extensions"], stats
assert 40 <= stats["mime_patterns"], stats
for application in catalog.applications:
    assert application.purpose.strip(), application.id
    assert application.maturity in {"mature", "stable", "beta", "experimental", "legacy"}, application.id
    assert application.usefulness in {"primary", "general", "specialized", "companion", "fallback"}, application.id
    assert 0 <= application.popularity <= 100, application.id
    assert application.handles, application.id
    assert application.install, application.id
    assert any(key in application.install for key in ("apt", "flatpak", "snap", "url")), application.id

# 2. Matching is specific before it is broad.
gimp = catalog.get("org.gimp.GIMP")
assert gimp is not None
png_match = next(match for match in catalog.matches("image/png", "png", "image", index)
                 if match.application.id == "org.gimp.GIMP")
assert png_match.match_score >= 100, png_match
markdown = catalog.matches("text/markdown", "md", "text", index)
assert any(match.application.id == "com.obsidian.Obsidian" for match in markdown), markdown

# 3. Install hints are generated in the expected commands.
commands = install_commands(gimp)
assert any(command["method"] == "apt" and "gimp" in command["command"] for command in commands)
assert any(command["method"] == "flatpak" and "org.gimp.GIMP" in command["command"]
           for command in commands)
assert preferred_install(gimp) is not None

# 4. Installed applications rank first; catalog suggestions follow.
identification = identify(os.path.join(os.environ["FILETYPE_FIXTURES"], "sample.png"), index)
recommendation = recommend(identification, applications, catalog, index)
assert recommendation.unhandled is False
assert recommendation.installed, recommendation.installed
assert recommendation.installed[0].name == "Test Image Viewer", recommendation.installed[0]
assert any(application.identifier == "org.gimp.GIMP" for application in recommendation.available)
assert all(application.reasons for application in recommendation.available)

# 5. An unknown type still gets fallback suggestions, and is flagged.
unknown = identify(os.path.join(os.environ["FILETYPE_FIXTURES"], "sample.custom"), index)
assert unknown.mime == "application/x-custom-format"
fallback = recommend(unknown, applications, catalog, index)
assert fallback.unhandled is True
assert fallback.available, "an unknown type should still offer something"
assert fallback.notes

# 6. A malformed catalog is refused with the offending entry named.
bad = {
    "schema": 1,
    "applications": [{
        "id": "bad.app", "name": "Bad", "purpose": "Bad entry",
        "kind": "gui", "maturity": "ancient", "popularity": 10,
        "usefulness": "general", "handles": {"categories": ["text"]}, "install": {}
    }],
}
try:
    ApplicationCatalog.from_document(bad)
except CatalogError as error:
    assert "maturity" in str(error), error
else:
    raise AssertionError("a malformed catalog was accepted")

# 7. Duplicate identifiers are refused.
duplicate = {"schema": 1, "applications": [
    {"id": "same", "name": "A", "purpose": "A", "kind": "gui", "maturity": "stable",
     "popularity": 1, "usefulness": "general", "handles": {"categories": ["text"]}, "install": {}},
    {"id": "same", "name": "B", "purpose": "B", "kind": "gui", "maturity": "stable",
     "popularity": 1, "usefulness": "general", "handles": {"categories": ["text"]}, "install": {}},
]}
try:
    ApplicationCatalog.from_document(duplicate)
except CatalogError as error:
    assert "duplicate" in str(error), error
else:
    raise AssertionError("a duplicate identifier was accepted")

print("30-application-catalog: ok")
PY
exit 0

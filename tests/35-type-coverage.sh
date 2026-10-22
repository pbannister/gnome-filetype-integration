#!/bin/sh
#
# Prove that every known file type gets at least one candidate application.
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
import os
from pathlib import Path

from filetype_integration.application_catalog import ApplicationCatalog, recommend
from filetype_integration.desktop_application import ApplicationIndex
from filetype_integration.file_identifier import ExtensionHint, Identification, MagicResult
from filetype_integration.mime_index import TypeIndex

index = TypeIndex.load()
installed = ApplicationIndex(index=index, use_gio=False)
catalog = ApplicationCatalog.load()
checked = 0
missing = []
for mime in sorted(index.types):
    if mime.startswith("inode/"):
        continue
    extensions = index.extensions_for(mime)
    extension = extensions[0] if extensions else ""
    identification = Identification(
        path=Path("question.custom"),
        mime=mime,
        description=index.description(mime),
        category=index.category(mime),
        category_label=index.category(mime),
        source="mime",
        confidence=1.0,
        magic=MagicResult(mime=mime),
        extension=ExtensionHint(suffix=extension, mime=mime),
        exists=True,
    )
    recommendation = recommend(identification, installed, catalog, index)
    checked += 1
    if not recommendation.installed and not recommendation.available:
        missing.append((mime, index.category(mime)))
assert checked >= 10, checked
assert not missing, missing[:10]
print(f"35-type-coverage: ok ({checked} fixture types)")
PY
exit 0

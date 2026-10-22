#!/bin/sh
#
# Test the MIME index: globs, weights, compound extensions, aliases,
# subclasses, categories, and descriptions, all from the fixture database.
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
from filetype_integration.mime_index import TypeIndex, category_of

index = TypeIndex.load()

# The fixture is the only MIME source; the real /etc/mime.types must not leak in.
sources = " ".join(str(path) for path in index.source_files)
assert "/etc/mime.types" not in sources, sources
assert "/usr/share/mime" not in sources, sources
assert 10 <= index.type_count() <= 60, index.type_count()

# 1. Simple and compound extensions.
assert index.lookup_extension("photo.png")[0].mime == "image/png"
assert index.lookup_extension("photo.PNG")[0].mime == "image/png"
assert index.lookup_extension("archive.tar.gz")[0].mime == "application/x-compressed-tar"
assert index.lookup_extension("archive.gz")[0].mime == "application/gzip"
assert index.lookup_extension("notes.unknown") == []
assert index.lookup_extension(".bashrc") == []

# 2. The extension index is searchable in both directions.
assert "tar.gz" in index.extensions_for("application/x-compressed-tar")
assert "png" in index.extensions_for("image/png")
assert index.lookup_extension_name("custom").mime == "application/x-custom-format"
assert index.lookup_extension_name(".custom").mime == "application/x-custom-format"

# 3. Aliases and ancestors.
assert index.canonical("application/x-pdf") == "application/pdf"
assert "application/x-pdf" in index.aliases_for("application/pdf")
assert "application/gzip" in index.ancestors("application/x-compressed-tar")
assert "application/zip" in index.ancestors(
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document")

# 4. Odd ancestry is not used to widen a handler search.
handler_family = index.handler_family("text/x-python")
assert "application/x-executable" not in handler_family, handler_family
assert "text/plain" in handler_family, handler_family

# 5. Categories and descriptions.
assert index.category("image/png") == "image"
assert index.category("text/x-python") == "code"
assert index.category("text/markdown") == "text"
assert index.category("application/pdf") == "document"
assert index.category("application/x-compressed-tar") == "archive"
assert index.category("application/x-custom-format") == "data"
assert index.description("image/png") == "PNG image"
assert index.description("text/x-python") == "Python script"
assert index.description("application/pdf") == "PDF document"
assert index.icon("image/png") == "image-png"
assert index.generic_icon("text/x-python") == "text-x-script"

# 6. XML and globs2 agree; the longest pattern wins at equal weight.
match = index.lookup_extension("x.tar.gz")[0]
assert match.pattern == "*.tar.gz", match
assert match.specificity > index.lookup_extension("x.gz")[0].specificity
print("20-mime-index: ok")
PY
exit 0

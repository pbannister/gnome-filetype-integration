#!/bin/sh
#
# program-build.sh: stage the Python program and generate build-time version
# information.
#
# Usage: program-build.sh
#
# Output:
#   dataflow.out/build/program/bin/filetype
#   dataflow.out/build/program/lib/gnome-filetype-integration/...
#   dataflow.out/build/generated/version_info.{h,py}
#   dataflow.out/catalog-stats.json
#
# The staged program is what make install copies and what the tests execute,
# so a test never depends on an unbuilt source tree.
set -eu

DIRECTORY_SCRIPT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$DIRECTORY_SCRIPT/.." && pwd)
DIRECTORY_BUILD="$REPOSITORY_ROOT/dataflow.out/build"
DIRECTORY_PROGRAM="$DIRECTORY_BUILD/program"
DIRECTORY_LIBRARY="$DIRECTORY_PROGRAM/lib/gnome-filetype-integration"
DIRECTORY_GENERATED="$DIRECTORY_BUILD/generated"

rm -rf "$DIRECTORY_PROGRAM"
mkdir -p "$DIRECTORY_LIBRARY" "$DIRECTORY_PROGRAM/bin" "$DIRECTORY_GENERATED"

sh "$REPOSITORY_ROOT/scripts/version-generate.sh"

cp -R "$REPOSITORY_ROOT/sources/filetype_integration/." "$DIRECTORY_LIBRARY/filetype_integration/"
find "$DIRECTORY_LIBRARY" -type d -name '__pycache__' -prune -exec rm -rf {} +
cp "$DIRECTORY_GENERATED/version_info.py" "$DIRECTORY_LIBRARY/filetype_integration/version_info.py"

cat > "$DIRECTORY_PROGRAM/bin/filetype" <<'PY'
#!/usr/bin/env python3
"""Installed launcher for the file type integration."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
LIBRARY = os.path.normpath(os.path.join(HERE, "..", "lib", "gnome-filetype-integration"))
sys.path.insert(0, LIBRARY)

from filetype_integration.cli import main

if __name__ == "__main__":
    raise SystemExit(main())
PY
chmod 755 "$DIRECTORY_PROGRAM/bin/filetype"

PYTHONPATH="$DIRECTORY_LIBRARY" python3 -m compileall -q "$DIRECTORY_LIBRARY"
find "$DIRECTORY_LIBRARY" -type d -name '__pycache__' -prune -exec rm -rf {} +
PYTHONPATH="$DIRECTORY_LIBRARY" python3 - "$REPOSITORY_ROOT/dataflow.out/catalog-stats.json" <<'PY'
import sys
from filetype_integration.catalog_export import build_report
from pathlib import Path
import json
report = build_report()
Path(sys.argv[1]).write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(f"program-build: catalog report: {sys.argv[1]}")
print(f"program-build: {report['types']} MIME types, {report['extensions']} extensions, "
      f"{report['catalog']['applications']} catalog applications, "
      f"{report['unhandled_types']} types without an installed handler")
if report["types_without_suggestion"]:
    print(f"program-build: {report['types_without_suggestion']} known types have no "
          f"installed or suggested application: "
          f"{report['types_without_suggestion_examples']}", file=sys.stderr)
    raise SystemExit(1)
PY

# The catalog export imports the package; bytecode written during that check
# is build debris, not part of the install.
find "$DIRECTORY_LIBRARY" -type d -name '__pycache__' -prune -exec rm -rf {} +

echo "program-build: staged $DIRECTORY_PROGRAM"

#!/usr/bin/env python3
"""Build-time catalog coverage report.

The report is generated output: it describes the MIME database and the
catalog on the machine that ran the build.  The site dashboard reads it, and
``catalog stats`` prints the same facts on demand.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

from .application_catalog import ApplicationCatalog
from .desktop_application import ApplicationIndex
from .desktop_integration import handler_mime_types
from .mime_index import TypeIndex
from .version import version_string


def build_report(index: TypeIndex | None = None,
                 installed: ApplicationIndex | None = None,
                 catalog: ApplicationCatalog | None = None) -> dict[str, object]:
    index = index or TypeIndex.load()
    installed = installed or ApplicationIndex(index=index)
    catalog = catalog or ApplicationCatalog.load()
    types = handler_mime_types(index)
    unhandled = 0
    without_suggestion: list[str] = []
    for mime in types:
        usable = installed.for_mime(mime, include_unavailable=False)
        if not usable:
            unhandled += 1
        extensions = index.extensions_for(mime)
        extension = extensions[0] if extensions else ""
        suggestions = catalog.matches(mime, extension=extension,
                                      category=index.category(mime), index=index)
        if not usable and not suggestions:
            without_suggestion.append(mime)
    category_counts: dict[str, int] = {}
    for mime in index.types:
        category = index.category(mime)
        category_counts[category] = category_counts.get(category, 0) + 1
    return {
        "schema": 1,
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "version": version_string(),
        "types": index.type_count(),
        "extensions": index.extension_count(),
        "globs": len(index.globs),
        "categories": dict(sorted(category_counts.items())),
        "catalog": catalog.stats(),
        "installed_applications": len(installed.entries),
        "unhandled_types": unhandled,
        "handler_types": len(types),
        "types_without_suggestion": len(without_suggestion),
        "types_without_suggestion_examples": without_suggestion[:20],
        "sources": [str(path) for path in index.source_files],
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="catalog-export",
                                     description="Write the catalog coverage report.")
    parser.add_argument("--output", default="-", help="output file, or - for standard output")
    parser.add_argument("--json", action="store_true", help="accepted for symmetry; the report is JSON")
    arguments = parser.parse_args(argv)
    report = build_report()
    text = json.dumps(report, indent=2, sort_keys=False) + "\n"
    if arguments.output == "-":
        sys.stdout.write(text)
    else:
        path = Path(arguments.output)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
        print(f"catalog-export: wrote {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

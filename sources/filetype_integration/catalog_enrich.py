"""Enrich the catalog from Flathub application pages.

A Flathub page links to the upstream project under "Project Website".  That is
the best lead for an application whose catalog entry only names a Flatpak id.
This is an explicit, network-using maintenance command; it is not part of the
portable build or test suite.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

from .application_catalog import ApplicationCatalog, DEFAULT_CATALOG_PATH
from .about_links import USER_AGENT

FLATHUB_APP = "https://flathub.org/apps/{identifier}"
HOMEPAGE_PATTERNS = (
    re.compile(r'\\"homepage\\"\s*:\s*\\"(https?://[^"\\]+)'),
    re.compile(r'"homepage"\s*:\s*"(https?://[^"]+)"'),
)


def _fetch(url: str, timeout: float = 15.0) -> str:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return response.read().decode("utf-8", "replace")
    except (urllib.error.URLError, TimeoutError, OSError):
        return ""


def extract_flathub_homepage(html: str) -> str:
    """Return the upstream project URL from a Flathub app page, or empty."""
    if not html:
        return ""
    visible = html.find("Project Website")
    if visible != -1:
        prefix = html[max(0, visible - 4000):visible]
        matches = re.findall(r'href="(https?://[^"]+)"', prefix)
        if matches:
            candidate = matches[-1]
            if "flathub.org" not in candidate:
                return candidate
    for pattern in HOMEPAGE_PATTERNS:
        match = pattern.search(html)
        if match:
            candidate = match.group(1).replace("\\/", "/")
            if "flathub.org" not in candidate:
                return candidate
    return ""


def enrich(catalog_path: Path | str = DEFAULT_CATALOG_PATH,
           workers: int = 8, dry_run: bool = False) -> dict[str, object]:
    path = Path(catalog_path)
    data = json.loads(path.read_text(encoding="utf-8"))
    targets = [application for application in data["applications"]
               if application.get("install", {}).get("flatpak")
               and not application.get("homepage")]
    found: dict[str, str] = {}
    failed: list[str] = []

    def work(application: dict[str, object]) -> tuple[str, str]:
        identifier = str(application["id"])
        flatpak = str(application["install"]["flatpak"])  # type: ignore[index]
        html = _fetch(FLATHUB_APP.format(identifier=flatpak))
        return identifier, extract_flathub_homepage(html)

    with ThreadPoolExecutor(max_workers=max(1, workers)) as pool:
        futures = {pool.submit(work, application): application for application in targets}
        for future in as_completed(futures):
            identifier, homepage = future.result()
            if homepage:
                found[identifier] = homepage
            else:
                failed.append(identifier)

    if not dry_run:
        for application in data["applications"]:
            if application["id"] in found:
                application["homepage"] = found[application["id"]]
        path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")

    return {
        "candidates": len(targets),
        "found": len(found),
        "failed": sorted(failed),
        "dry_run": dry_run,
        "path": str(path),
        "homepages": dict(sorted(found.items())),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="catalog-enrich",
        description="Fill missing catalog homepages from Flathub project pages.")
    parser.add_argument("--catalog", default=str(DEFAULT_CATALOG_PATH))
    parser.add_argument("--workers", type=int, default=8)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--json", action="store_true")
    arguments = parser.parse_args(argv)
    try:
        report = enrich(arguments.catalog, arguments.workers, arguments.dry_run)
    except (OSError, json.JSONDecodeError) as error:
        print(f"catalog-enrich: {error}", file=sys.stderr)
        return 1
    if arguments.json:
        print(json.dumps(report, indent=2, sort_keys=False))
    else:
        print(f"catalog-enrich: {report['found']}/{report['candidates']} homepages found"
              f"{' (dry run)' if report['dry_run'] else ''}")
        for identifier, homepage in report["homepages"].items():  # type: ignore[union-attr]
            print(f"  {identifier}: {homepage}")
        if report["failed"]:
            print(f"  no homepage found: {', '.join(report['failed'])}")  # type: ignore[arg-type]
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/bin/sh
#
# Live-state check: probe the first few About candidates for a sample of
# catalog applications and fail when an application has no reachable page.
#
# Tier: live-state. Requires network access, and runs only when explicitly
# asked: FILETYPE_LIVE=1 sh tests/51-about-live.sh
#
# `make test` skips it, because the portable suite must not depend on the
# outside network.
set -eu

DIRECTORY_SCRIPT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$DIRECTORY_SCRIPT/.." && pwd)
. "$DIRECTORY_SCRIPT/lib/test_helpers.sh"
skip_unless_tool python3

if [ "${FILETYPE_LIVE:-0}" != 1 ]; then
    skip_test 'live-state: set FILETYPE_LIVE=1 to probe About URLs'
fi

PYTHONPATH="$REPOSITORY_ROOT/sources${PYTHONPATH:+:$PYTHONPATH}" python3 - <<'PY'
from concurrent.futures import ThreadPoolExecutor
from filetype_integration.about_links import probe_url
from filetype_integration.application_catalog import ApplicationCatalog, about_candidates

catalog = ApplicationCatalog.load()
sample = [
    "org.libreoffice.LibreOffice", "org.gimp.GIMP", "org.blender.Blender",
    "org.inkscape.Inkscape", "org.videolan.VLC", "org.mozilla.firefox",
    "org.mozilla.Thunderbird", "org.freecad.FreeCAD", "org.openscad.OpenSCAD",
    "org.kicad.KiCad", "org.audacityteam.Audacity", "org.kde.kdenlive",
    "com.obsproject.Studio", "org.keepassxc.KeePassXC", "qgis",
    "com.calibre_ebook.calibre", "com.github.johnfactotum.Foliate",
    "com.github.xournalpp.xournalpp", "org.kde.okular", "org.gnome.Nautilus",
]


def check(identifier):
    application = catalog.get(identifier)
    assert application is not None, identifier
    candidates = about_candidates(application, None)[:3]
    for url in candidates:
        if probe_url(url, timeout=6):
            return identifier, url, candidates
    return identifier, "", candidates


failures = []
with ThreadPoolExecutor(max_workers=8) as pool:
    for identifier, url, candidates in pool.map(check, sample):
        if url:
            print(f"PASS {identifier} -> {url}")
        else:
            print(f"FAIL {identifier} -> tried {candidates}")
            failures.append(identifier)
if failures:
    raise SystemExit(f"no About candidate answered for: {', '.join(failures)}")
print(f"51-about-live: ok ({len(sample)} applications)")
PY

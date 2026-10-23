#!/bin/sh
#
# Test the About candidate list and the live URL probe against a local HTTP
# server, including the GET fallback for a server that rejects HEAD.
#
# Tier: portable (python3, loopback network only).
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
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

os.environ["no_proxy"] = "127.0.0.1,localhost"
os.environ["NO_PROXY"] = "127.0.0.1,localhost"

from filetype_integration import about_links
from filetype_integration.application_catalog import (ApplicationCatalog, _catalog_entry_for,
                                                       about_candidates, recommend)
from filetype_integration.catalog_enrich import (extract_debian_homepage,
                                                   extract_flathub_homepage)
from filetype_integration.desktop_application import ApplicationIndex, InstalledApplication
from filetype_integration.file_identifier import identify
from filetype_integration.mime_index import TypeIndex

request_counts = {}


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_args):
        pass

    def _count(self):
        request_counts[self.path] = request_counts.get(self.path, 0) + 1

    def do_HEAD(self):
        self._count()
        if self.path == "/ok":
            self.send_response(200)
            self.send_header("Content-Length", "0")
            self.end_headers()
        elif self.path == "/head-rejected":
            self.send_response(405)
            self.end_headers()
        else:
            self.send_response(404)
            self.end_headers()

    def do_GET(self):
        self._count()
        if self.path in {"/ok", "/head-rejected"}:
            self.send_response(200)
            self.send_header("Content-Length", "5")
            self.end_headers()
            self.wfile.write(b"hello")
        else:
            self.send_response(404)
            self.end_headers()


server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
base = f"http://127.0.0.1:{server.server_port}"

try:
    about_links.reset_cache()

    # 1. A missing page is false; a live page is true.
    assert about_links.probe_url(base + "/missing") is False
    assert about_links.probe_url(base + "/ok") is True
    # 2. A server that rejects HEAD is retried with GET.
    assert about_links.probe_url(base + "/head-rejected") is True
    # 3. The first live candidate wins and the missing one is recorded.
    found, results = about_links.find_first_available(
        [base + "/missing", base + "/ok", base + "/head-rejected"])
    assert found == base + "/ok", found
    assert [result.ok for result in results] == [False, True], results
    # 4. No candidate available is reported, not guessed.
    found, results = about_links.find_first_available([base + "/missing"])
    assert found == "" and len(results) == 1 and results[0].ok is False
    # 5. A successful probe is cached: the second check does not touch the
    #    server again.
    before = request_counts.get("/ok", 0)
    assert about_links.probe_url(base + "/ok") is True
    assert request_counts.get("/ok", 0) == before

    # 6. A catalog application has ordered, deduplicated candidates.
    catalog = ApplicationCatalog.load()
    gimp = catalog.get("org.gimp.GIMP")
    assert gimp.homepage == "https://www.gimp.org/"
    index = TypeIndex.load()
    installed = ApplicationIndex(index=index, use_gio=False)
    identification = identify(os.path.join(os.environ["FILETYPE_FIXTURES"], "sample.png"), index)
    recommendation = recommend(identification, installed, catalog, index)
    offer = next(item for item in recommendation.available
                 if item.identifier == "org.gimp.GIMP")
    urls = offer.about_urls
    assert urls[0] == "https://www.gimp.org/", urls
    assert "https://flathub.org/apps/org.gimp.GIMP" in urls, urls
    assert "https://tracker.debian.org/pkg/gimp" in urls, urls
    assert len(urls) == len(set(urls)), urls
    assert all(url.startswith(("http://", "https://")) for url in urls), urls

    # 7. Every catalog application has at least one alternative, and every
    #    URL is structurally usable (scheme, host, no whitespace).
    from urllib.parse import urlparse
    for application in catalog.applications:
        candidates = about_candidates(application, None)
        assert 2 <= len(candidates), (application.id, candidates)
        assert len(candidates) == len(set(candidates)), (application.id, candidates)
        for url in candidates:
            parsed = urlparse(url)
            assert parsed.scheme in {"http", "https"}, (application.id, url)
            assert parsed.netloc, (application.id, url)
            assert not any(character.isspace() for character in url), (application.id, url)

    # 8. A distribution that renames the desktop id and appends a version still
    #    finds the catalog entry and its alternatives.
    snap_calc = InstalledApplication(
        desktop_id="libreoffice_calc.desktop", name="LibreOffice 26.2 Calc",
        comment="", executable="/snap/bin/libreoffice.calc",
        exec_line="/snap/bin/libreoffice.calc %U", mime_types=["application/vnd.oasis.opendocument.spreadsheet"],
        source_path="/tmp/libreoffice_calc.desktop",
    )
    matched = _catalog_entry_for(snap_calc, catalog)
    assert matched is not None and matched.id == "org.libreoffice.LibreOffice", matched
    snap_urls = about_candidates(matched, snap_calc)
    assert snap_urls[0] == "https://www.libreoffice.org/", snap_urls
    assert any("tracker.debian.org" in url for url in snap_urls), snap_urls
    assert any("flathub.org" in url for url in snap_urls), snap_urls
    assert len(snap_urls) >= 3, snap_urls

    # 9. A GVim desktop entry uses the Vim catalog entry and reaches the
    #    project page, Wikipedia, and the source repository before any package
    #    search page.
    gvim = InstalledApplication(
        desktop_id="gvim.desktop", name="GVim", comment="",
        executable="gvim", exec_line="gvim %F",
        mime_types=["text/plain"], source_path="/tmp/gvim.desktop",
    )
    vim_entry = _catalog_entry_for(gvim, catalog)
    assert vim_entry is not None and vim_entry.id == "org.vim.Vim", vim_entry
    vim_urls = about_candidates(vim_entry, gvim)
    assert vim_urls[:3] == [
        "https://www.vim.org/",
        "https://en.wikipedia.org/wiki/Vim_(text_editor)",
        "https://github.com/vim/vim",
    ], vim_urls
    assert all("packages." not in url for url in vim_urls[:3]), vim_urls

    # 10. Helix prefers its project page, repository, documentation, and
    #     community before any distribution page, and no application uses a
    #     package search page (a search page answers 200 even with no result).
    helix = catalog.get("com.github.helix")
    helix_urls = about_candidates(helix, None)
    assert helix_urls[:4] == [
        "https://helix-editor.com/",
        "https://github.com/helix-editor/helix",
        "https://docs.helix-editor.com/",
        "https://www.reddit.com/r/HelixEditor/",
    ], helix_urls
    for application in catalog.applications:
        for url in about_candidates(application, None):
            assert "/search?" not in url and "search?q=" not in url, (application.id, url)

    # 11. Flathub pages carry the project website; the extractor handles both
    #     the visible "Project Website" link and the embedded JSON field.
    visible = ('<a href="https://www.gnu.org/software/emacs" target="_blank">'
               '<span>Project Website</span></a>')
    assert extract_flathub_homepage(visible) == "https://www.gnu.org/software/emacs"
    embedded = '\"homepage\":\"https://www.gnu.org/software/emacs\"'
    assert extract_flathub_homepage(embedded) == "https://www.gnu.org/software/emacs"
    assert extract_flathub_homepage("") == ""
    assert extract_flathub_homepage("<p>No website</p>") == ""

    # 12. GNU Emacs was enriched from its Flathub page, so the project page
    #     comes before the store page.
    emacs = catalog.get("org.gnu.emacs")
    assert emacs.homepage == "https://www.gnu.org/software/emacs", emacs.homepage
    emacs_urls = about_candidates(emacs, None)
    assert emacs_urls[0] == "https://www.gnu.org/software/emacs", emacs_urls
    assert "https://flathub.org/apps/org.gnu.emacs" in emacs_urls, emacs_urls
    assert emacs_urls.index("https://www.gnu.org/software/emacs") < emacs_urls.index(
        "https://flathub.org/apps/org.gnu.emacs"), emacs_urls

    # 13. Debian tracker pages carry the upstream homepage. csvkit is the
    #     concrete case whose Debian source README also links the docs.
    tracker = ('<a href="https://github.com/wireservice/csvkit"'
               ' title="upstream web homepage">homepage</a>')
    assert extract_debian_homepage(tracker) == "https://github.com/wireservice/csvkit"
    assert extract_debian_homepage("<p>no homepage</p>") == ""
    csvkit = catalog.get("csvkit")
    assert csvkit.homepage == "https://github.com/wireservice/csvkit", csvkit.homepage
    assert "https://csvkit.readthedocs.io/" in csvkit.about, csvkit.about
    csvkit_urls = about_candidates(csvkit, None)
    assert csvkit_urls[0] == "https://github.com/wireservice/csvkit", csvkit_urls
    assert "https://csvkit.readthedocs.io/" in csvkit_urls, csvkit_urls
    assert all("/search?" not in url for url in csvkit_urls), csvkit_urls

    # 14. PrusaSlicer's project page moved; the catalog carries the canonical
    #     URL and the reviewable homepage wins over stale AppStream metadata.
    prusa = catalog.get("com.prusa3d.PrusaSlicer")
    assert prusa.homepage == "https://www.prusa3d.com/p/prusaslicer/", prusa.homepage
    import filetype_integration.application_catalog as catalog_module
    original_homepage = catalog_module.application_homepage
    catalog_module.application_homepage = lambda _desktop: "https://www.prusa3d.com/prusaslicer/"
    try:
        prusa_desktop = InstalledApplication(
            desktop_id="com.prusa3d.PrusaSlicer.desktop", name="PrusaSlicer",
            comment="", executable="/usr/bin/prusa-slicer",
            exec_line="/usr/bin/prusa-slicer %F",
            mime_types=["model/stl"], source_path="/tmp/com.prusa3d.PrusaSlicer.desktop",
        )
        prusa_urls = about_candidates(prusa, prusa_desktop)
    finally:
        catalog_module.application_homepage = original_homepage
    assert prusa_urls[0] == "https://www.prusa3d.com/p/prusaslicer/", prusa_urls
    assert "https://github.com/prusa3d/PrusaSlicer" in prusa_urls, prusa_urls
    assert "https://www.prusa3d.com/prusaslicer/" not in prusa_urls, prusa_urls

    # 15. AppImage Activator has a catalog entry, so its About links name the
    #     integrating project instead of packages guessed from its local path.
    activator = InstalledApplication(
        desktop_id="appimage-activator.desktop", name="AppImage Activator",
        comment="", executable="/home/user/.local/bin/appimage-integrate",
        exec_line="/home/user/.local/bin/appimage-integrate handle %f",
        mime_types=["application/vnd.appimage"], source_path="/tmp/appimage-activator.desktop",
    )
    activator_entry = _catalog_entry_for(activator, catalog)
    assert activator_entry is not None and activator_entry.id == (
        "com.github.pbannister.AppImageActivator"), activator_entry
    activator_urls = about_candidates(activator_entry, activator)
    assert activator_urls[0] == (
        "https://labs.bannister.us/projects/gnome-appimage-integration/"), activator_urls
    assert "https://github.com/pbannister/gnome-appimage-integration" in activator_urls, activator_urls
    assert "https://github.com/pbannister/gnome-appimage-integration/releases" in activator_urls, activator_urls
    assert all("tracker.debian.org" not in url for url in activator_urls), activator_urls

    # 16. An uncataloged AppImage offers no fabricated package page: its local
    #     path is not a package name, and a reverse-DNS desktop id is not one.
    uncataloged = InstalledApplication(
        desktop_id="com.example.Viewer.desktop", name="Example Viewer",
        comment="", executable="/home/user/Applications/Example-Viewer.AppImage",
        exec_line="/home/user/Applications/Example-Viewer.AppImage %f",
        mime_types=["application/vnd.appimage"], source_path="/tmp/com.example.Viewer.desktop",
    )
    assert _catalog_entry_for(uncataloged, catalog) is None
    assert about_candidates(None, uncataloged) == []

    print("40-about-links: ok")
finally:
    server.shutdown()
    server.server_close()
PY
exit 0

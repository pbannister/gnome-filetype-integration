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

    print("40-about-links: ok")
finally:
    server.shutdown()
    server.server_close()
PY
exit 0

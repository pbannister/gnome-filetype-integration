#!/bin/sh
#
# Test the About history and its once-per-day rule, plus the concurrency of
# the HEAD checks and the category grouping.
#
# Tier: portable (python3, loopback network only).
set -eu

DIRECTORY_SCRIPT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$DIRECTORY_SCRIPT/lib/filetype_env.sh"
. "$DIRECTORY_SCRIPT/lib/test_helpers.sh"
skip_unless_tool python3

filetype_sandbox
trap filetype_cleanup EXIT HUP INT TERM

PYTHONPATH="$REPOSITORY_ROOT/sources${PYTHONPATH:+:$PYTHONPATH}" python3 - <<'PY'
import os
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

os.environ["no_proxy"] = "127.0.0.1,localhost"
os.environ["NO_PROXY"] = "127.0.0.1,localhost"

from filetype_integration import about_links
from filetype_integration.application_catalog import (ApplicationCatalog,
                                                       about_candidates)
from filetype_integration.about_links import (AboutLink, category_for_url,
                                               check_about_urls, group_links,
                                               history_entries, link_label,
                                               load_history)

counts = {}
lock = threading.Lock()


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_args):
        pass

    def _count(self):
        with lock:
            counts[self.path] = counts.get(self.path, 0) + 1

    def do_HEAD(self):
        self._count()
        if self.path.startswith("/slow"):
            time.sleep(0.4)
            self.send_response(200)
            self.send_header("Content-Length", "0")
            self.end_headers()
        elif self.path == "/ok":
            self.send_response(200)
            self.send_header("Content-Length", "0")
            self.end_headers()
        else:
            self.send_response(404)
            self.end_headers()

    def do_GET(self):
        self._count()
        self.send_response(404 if self.path == "/missing" else 200)
        self.end_headers()


server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
base = f"http://127.0.0.1:{server.server_port}"

try:
    about_links.reset_cache()
    missing = base + "/missing"
    ok = base + "/ok"

    # 1. Two links are checked concurrently and recorded.
    results = check_about_urls([missing, ok], max_workers=2)
    assert results[missing].ok is False
    assert results[ok].ok is True
    assert counts.get("/ok") == 1, counts
    assert counts.get("/missing") >= 1, counts
    entries = {entry["url"]: entry for entry in history_entries()}
    assert entries[ok]["ok"] is True
    assert entries[missing]["ok"] is False
    assert entries[ok]["last_checked"] == entries[missing]["last_checked"]
    assert entries[ok]["last_checked"], entries

    # 2. A second check on the same day does not touch the server.
    before = dict(counts)
    results = check_about_urls([missing, ok], max_workers=2)
    assert counts == before, (before, counts)
    assert results[ok].from_cache is True and results[ok].checked_today is True
    assert results[missing].from_cache is True

    # 3. A check dated yesterday is repeated.
    history = load_history()
    history["sites"][ok]["last_checked"] = "2000-01-01"
    about_links.save_history(history)
    before = counts.get("/ok", 0)
    check_about_urls([ok], max_workers=1, force=True)
    assert counts.get("/ok", 0) == before + 1, counts

    # 4. Four slow checks run concurrently, not serially.
    slow = [f"{base}/slow/{index}" for index in range(4)]
    started = time.monotonic()
    results = check_about_urls(slow, max_workers=4, force=True)
    elapsed = time.monotonic() - started
    assert all(result.ok for result in results.values()), results
    assert elapsed < 1.2, f"four 0.4s checks took {elapsed:.2f}s; not concurrent"

    # 5. Grouping preserves the relevance order and uses useful categories.
    catalog = ApplicationCatalog.load()
    urls = about_candidates(catalog.get("com.github.helix"), None)
    links = [AboutLink(url=url, category=category_for_url(url), label=link_label(url))
             for url in urls]
    groups = group_links(links)
    assert [category for category, _ in groups] == [
        "Project", "Repository", "Documentation", "Community", "Package"], groups
    assert groups[0][1][0].url == "https://helix-editor.com/", groups
    assert groups[1][1][0].url == "https://github.com/helix-editor/helix", groups
    print("41-about-history: ok")
finally:
    server.shutdown()
    server.server_close()
PY
exit 0

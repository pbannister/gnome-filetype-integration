"""Choose a working About URL.

The catalog records where an application is described, but a project page,
Flathub page, or distribution page can disappear.  The chooser keeps every
candidate it can derive and probes them in order with a short HEAD request,
falling back to a one-byte GET for servers that reject HEAD.  The first one
that answers is opened; a failure moves to the next candidate.
"""

from __future__ import annotations

import shutil
import subprocess
import threading
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from urllib.parse import urlparse

DEFAULT_TIMEOUT = 4.0
CACHE_TTL = 300.0
USER_AGENT = "gnome-filetype-integration/1 (About link check)"

_CACHE: dict[str, tuple[float, bool]] = {}
_CACHE_LOCK = threading.Lock()


@dataclass
class ProbeResult:
    url: str
    ok: bool
    status: int = 0
    error: str = ""

    def to_dict(self) -> dict[str, object]:
        return {"url": self.url, "ok": self.ok, "status": self.status,
                "error": self.error}


def _cached(url: str) -> bool | None:
    with _CACHE_LOCK:
        entry = _CACHE.get(url)
        if entry is None:
            return None
        stamp, ok = entry
        if CACHE_TTL <= time.monotonic() - stamp:
            del _CACHE[url]
            return None
        return ok


def _remember(url: str, ok: bool) -> None:
    with _CACHE_LOCK:
        _CACHE[url] = (time.monotonic(), ok)


def reset_cache() -> None:
    with _CACHE_LOCK:
        _CACHE.clear()


def _request(url: str, method: str, timeout: float) -> tuple[bool, int, str]:
    headers = {"User-Agent": USER_AGENT, "Accept": "*/*"}
    if method == "GET":
        headers["Range"] = "bytes=0-0"
    request = urllib.request.Request(url, method=method, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            status = int(getattr(response, "status", 0) or 0)
            response.read(1)
            return 200 <= status < 400, status, ""
    except urllib.error.HTTPError as error:
        return False, int(error.code or 0), str(error)
    except (urllib.error.URLError, TimeoutError, OSError, ValueError) as error:
        return False, 0, str(error)


def probe_url(url: str, timeout: float = DEFAULT_TIMEOUT,
              use_cache: bool = True) -> bool:
    """True when a short request reaches the site with a successful status."""
    parsed = urlparse(url)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        return False
    if use_cache:
        cached = _cached(url)
        if cached is not None:
            return cached
    ok, status, _error = _request(url, "HEAD", timeout)
    # Some servers reject HEAD with 400/403/405/501.  Ask for one byte with
    # GET instead; that still proves the page exists without downloading it.
    if not ok and status in {0, 400, 403, 405, 501}:
        ok, _status, _error = _request(url, "GET", timeout)
    _remember(url, ok)
    return ok


def find_first_available(urls: list[str], timeout: float = DEFAULT_TIMEOUT,
                    probe=None) -> tuple[str, list[ProbeResult]]:
    """Probe candidates in order and return the first that answers."""
    probe = probe or probe_url
    results: list[ProbeResult] = []
    for url in urls:
        if not url:
            continue
        ok = bool(probe(url, timeout=timeout))
        results.append(ProbeResult(url=url, ok=ok))
        if ok:
            return url, results
    return "", results


def open_uri(url: str) -> bool:
    """Open a verified URL with the desktop's default browser."""
    if not url:
        return False
    try:
        from gi.repository import Gio  # type: ignore
    except (ImportError, ValueError):
        Gio = None  # type: ignore
    if Gio is not None:
        try:
            return bool(Gio.AppInfo.launch_default_for_uri(url, None))
        except Exception:
            return False
    executable = shutil.which("xdg-open")
    if executable is None:
        return False
    try:
        subprocess.Popen([executable, url], stdin=subprocess.DEVNULL,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         start_new_session=True, close_fds=True)
        return True
    except OSError:
        return False

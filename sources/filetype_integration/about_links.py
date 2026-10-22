"""Choose and track the pages behind an application's About link.

Every application has an ordered candidate list.  The About window shows the
list grouped by kind, keeps each link disabled until a short HTTP request
succeeds, and probes the list concurrently.  A site is visited at most once per
day; the visit history records the date, the result, and the status for later
inspection.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import threading
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from urllib.parse import urlparse

from . import paths

DEFAULT_TIMEOUT = 4.0
CACHE_TTL = 300.0
USER_AGENT = "gnome-filetype-integration/1 (About link check)"
STATE_VERSION = 1
CATEGORY_ORDER = (
    "Project",
    "Repository",
    "Documentation",
    "Reference",
    "Community",
    "Store",
    "Package",
)

_CACHE: dict[str, tuple[float, ProbeResult]] = {}
_CACHE_LOCK = threading.Lock()
_STATE_LOCK = threading.Lock()


@dataclass(frozen=True)
class AboutLink:
    url: str
    category: str
    label: str = ""

    def to_dict(self) -> dict[str, object]:
        return {"url": self.url, "category": self.category, "label": self.label}


@dataclass
class ProbeResult:
    url: str
    ok: bool
    status: int = 0
    error: str = ""
    from_cache: bool = False
    checked_today: bool = False

    def to_dict(self) -> dict[str, object]:
        return {
            "url": self.url,
            "ok": self.ok,
            "status": self.status,
            "error": self.error,
            "from_cache": self.from_cache,
            "checked_today": self.checked_today,
        }


def category_for_url(url: str) -> str:
    host = urlparse(url).netloc.lower()
    path = urlparse(url).path.lower()
    if any(marker in host for marker in
           ("github.", "gitlab.", "bitbucket.", "codeberg.", "git.sr.ht")):
        return "Repository"
    if host.startswith("docs.") or "readthedocs" in host or host.startswith("wiki."):
        return "Documentation"
    if "wikipedia.org" in host:
        return "Reference"
    if "reddit.com" in host or "discourse" in host or "forum" in host:
        return "Community"
    if "flathub.org" in host or "snapcraft.io" in host:
        return "Store"
    if any(marker in host for marker in
           ("tracker.debian.org", "sources.debian.org", "launchpad.net",
            "repology.org", "packages.ubuntu.com", "packages.debian.org")):
        return "Package"
    return "Project"


def link_label(url: str) -> str:
    parsed = urlparse(url)
    host = parsed.netloc.removeprefix("www.")
    path = parsed.path.rstrip("/")
    if path and path != "":
        return f"{host}{path}"
    return host or url


def group_links(links: list[AboutLink]) -> list[tuple[str, list[AboutLink]]]:
    groups: dict[str, list[AboutLink]] = {}
    for link in links:
        groups.setdefault(link.category, []).append(link)
    return [(category, groups[category]) for category in CATEGORY_ORDER
            if category in groups]


def state_path() -> Path:
    return paths.about_history_path()


def _today() -> str:
    return datetime.now().astimezone().date().isoformat()


def load_history() -> dict[str, object]:
    path = state_path()
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {"version": STATE_VERSION, "sites": {}}
    if not isinstance(raw, dict) or not isinstance(raw.get("sites"), dict):
        return {"version": STATE_VERSION, "sites": {}}
    return {"version": STATE_VERSION, "sites": dict(raw["sites"])}


def save_history(history: dict[str, object]) -> None:
    path = state_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.tmp-{os.getpid()}")
    temporary.write_text(json.dumps(history, indent=2, sort_keys=False) + "\n",
                         encoding="utf-8")
    os.replace(temporary, path)


def history_entries() -> list[dict[str, object]]:
    history = load_history()
    entries: list[dict[str, object]] = []
    for url, record in history.get("sites", {}).items():
        if not isinstance(record, dict):
            continue
        entries.append({
            "url": url,
            "last_checked": record.get("last_checked", ""),
            "checked_at": record.get("checked_at", ""),
            "ok": bool(record.get("ok")),
            "status": record.get("status", 0),
            "error": record.get("error", ""),
        })
    entries.sort(key=lambda entry: str(entry.get("checked_at", "")), reverse=True)
    return entries


def _cached(url: str) -> ProbeResult | None:
    with _CACHE_LOCK:
        entry = _CACHE.get(url)
        if entry is None:
            return None
        stamp, result = entry
        if CACHE_TTL <= time.monotonic() - stamp:
            del _CACHE[url]
            return None
        return ProbeResult(url=url, ok=result.ok, status=result.status,
                           error=result.error, from_cache=True,
                           checked_today=result.checked_today)


def _remember(result: ProbeResult) -> None:
    with _CACHE_LOCK:
        _CACHE[result.url] = (time.monotonic(), result)


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


def _probe(url: str, timeout: float = DEFAULT_TIMEOUT,
           use_cache: bool = True) -> ProbeResult:
    parsed = urlparse(url)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        return ProbeResult(url=url, ok=False, error="not an HTTP(S) URL")
    if use_cache:
        cached = _cached(url)
        if cached is not None:
            return cached
    ok, status, error = _request(url, "HEAD", timeout)
    if not ok and status in {0, 400, 403, 405, 501}:
        ok, status, error = _request(url, "GET", timeout)
    result = ProbeResult(url=url, ok=ok, status=status, error=error)
    _remember(result)
    return result


def probe_url(url: str, timeout: float = DEFAULT_TIMEOUT,
              use_cache: bool = True) -> bool:
    return _probe(url, timeout=timeout, use_cache=use_cache).ok


def check_about_urls(urls: list[str], timeout: float = DEFAULT_TIMEOUT,
                     max_workers: int = 8, force: bool = False,
                     on_result=None) -> dict[str, ProbeResult]:
    """Check URLs concurrently, at most once per local day.

    The history is shared by the CLI and the GUI.  A URL checked today is not
    requested again; its recorded result is returned instead.
    """
    history = load_history()
    sites = history.setdefault("sites", {})
    assert isinstance(sites, dict)
    today = _today()
    results: dict[str, ProbeResult] = {}
    pending: list[str] = []
    for url in dict.fromkeys(urls):
        record = sites.get(url)
        if (not force and isinstance(record, dict)
                and record.get("last_checked") == today):
            result = ProbeResult(
                url=url, ok=bool(record.get("ok")),
                status=int(record.get("status", 0) or 0),
                error=str(record.get("error", "")),
                from_cache=True, checked_today=True)
            results[url] = result
            if on_result is not None:
                on_result(result)
        else:
            pending.append(url)

    if pending:
        def work(url: str) -> ProbeResult:
            result = _probe(url, timeout=timeout, use_cache=not force)
            result.checked_today = True
            return result

        with ThreadPoolExecutor(max_workers=min(max_workers, len(pending))) as pool:
            futures = {pool.submit(work, url): url for url in pending}
            for future in as_completed(futures):
                url = futures[future]
                try:
                    result = future.result()
                except Exception as error:  # defensive: one bad URL cannot stop the rest
                    result = ProbeResult(url=url, ok=False, error=str(error),
                                         checked_today=True)
                results[url] = result
                with _STATE_LOCK:
                    current = load_history()
                    current_sites = current.setdefault("sites", {})
                    assert isinstance(current_sites, dict)
                    current_sites[url] = {
                        "last_checked": today,
                        "checked_at": datetime.now().astimezone().isoformat(timespec="seconds"),
                        "ok": result.ok,
                        "status": result.status,
                        "error": result.error,
                    }
                    save_history(current)
                if on_result is not None:
                    on_result(result)
    return results


def find_first_available(urls: list[str], timeout: float = DEFAULT_TIMEOUT,
                         probe=None, limit: int | None = None) -> tuple[str, list[ProbeResult]]:
    """Probe candidates in order and return the first that answers."""
    probe = probe or probe_url
    results: list[ProbeResult] = []
    candidates = urls[:limit] if limit else urls
    for url in candidates:
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

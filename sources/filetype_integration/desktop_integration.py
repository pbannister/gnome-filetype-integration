"""Register the chooser with the GNOME desktop, and take it out again.

The integration writes four things under ``$XDG_DATA_HOME``: a desktop
entry, an icon, an optional Nautilus extension, and a manifest.  It changes a
MIME default only when there is no working handler for that type, so an
existing association is never silently replaced.  The manifest records what
was written and what each type opened with before, so ``uninstall`` can put
the desktop back.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import tempfile
import time
from functools import lru_cache
from dataclasses import dataclass, field
from pathlib import Path

from . import paths
from .application_catalog import ApplicationCatalog
from .desktop_application import ApplicationIndex
from .file_launcher import handler_exec_path
from .mime_index import TypeIndex, normalize_mime
from .version import version_string

HANDLER_SCHEMA = 1
HANDLER_ICON_NAME = "filetype-chooser"
NAUTILUS_EXTENSION_SOURCE = Path(__file__).with_name("data") / "filetype_nautilus.py"
DEFAULT_APPLICATIONS = "Default Applications"


@dataclass
class InstallResult:
    ok: bool
    dry_run: bool = False
    manifest_path: str = ""
    desktop_entry: str = ""
    icon: str = ""
    handler_mime_types: int = 0
    defaults_set: int = 0
    already_handled: int = 0
    nautilus_extension: str = ""
    notes: list[str] = field(default_factory=list)
    written_files: list[str] = field(default_factory=list)
    commands: list[list[str]] = field(default_factory=list)

    def to_dict(self) -> dict[str, object]:
        return {
            "ok": self.ok,
            "dry_run": self.dry_run,
            "manifest_path": self.manifest_path,
            "desktop_entry": self.desktop_entry,
            "icon": self.icon,
            "handler_mime_types": self.handler_mime_types,
            "defaults_set": self.defaults_set,
            "already_handled": self.already_handled,
            "nautilus_extension": self.nautilus_extension,
            "notes": list(self.notes),
            "written_files": list(self.written_files),
            "commands": [list(command) for command in self.commands],
        }


@dataclass
class UninstallResult:
    ok: bool
    removed_files: list[str] = field(default_factory=list)
    restored_defaults: int = 0
    kept_user_defaults: int = 0
    notes: list[str] = field(default_factory=list)

    def to_dict(self) -> dict[str, object]:
        return {
            "ok": self.ok,
            "removed_files": list(self.removed_files),
            "restored_defaults": self.restored_defaults,
            "kept_user_defaults": self.kept_user_defaults,
            "notes": list(self.notes),
        }


FILE_MEDIA_TOP_LEVEL = frozenset(
    {"application", "audio", "chemical", "font", "image", "model", "text", "video"}
)
FILE_MESSAGE_TYPES = frozenset({"message/rfc822", "message/global", "message/news"})


def _sandbox_refusal() -> str:
    """Refuse a test install that escaped the temporary HOME.

    The test suite sets FILETYPE_INTEGRATION_REQUIRE_SANDBOX=1.  If a test
    accidentally inherits the real HOME, the install stops before writing
    anything, instead of changing the developer's desktop.
    """
    if os.environ.get("FILETYPE_INTEGRATION_REQUIRE_SANDBOX") != "1":
        return ""
    try:
        home = Path(os.environ.get("HOME", "")).resolve()
        temporary = Path(tempfile.gettempdir()).resolve()
    except OSError:
        return "the sandbox guard could not resolve HOME"
    if home == temporary or temporary in home.parents:
        return ""
    return (f"FILETYPE_INTEGRATION_REQUIRE_SANDBOX=1 refuses to write outside the "
            f"temporary directory: HOME={home}")


def handler_mime_types(index: TypeIndex) -> list[str]:
    """Every known file type, excluding objects that are not files.

    The handler claims file types.  It does not claim folders, URI schemes,
    volume types (``x-content/*``), or MIME body parts such as
    ``message/delivery-status`` that never arrive as a file.  Email files are
    kept because ``.eml`` and ``.mbox`` are real files.
    """
    result: list[str] = []
    for mime in sorted(index.types):
        canonical = index.canonical(mime)
        if canonical.startswith("inode/"):
            continue
        if canonical.startswith("x-scheme-handler/"):
            continue
        if canonical in {"application/x-missing-file"}:
            continue
        top_level = canonical.split("/", 1)[0]
        if top_level not in FILE_MEDIA_TOP_LEVEL and canonical not in FILE_MESSAGE_TYPES:
            continue
        if canonical not in result:
            result.append(canonical)
    return result


def desktop_quote(value: str) -> str:
    """Quote one Exec argument the way a desktop entry expects."""
    if not any(character in value for character in ' \t"\'\\$`'):
        return value
    escaped = value.replace("\\", "\\\\").replace('"', '\\"').replace("$", "\\$").replace("`", "\\`")
    return f'"{escaped}"'


def desktop_entry_text(executable: str, mime_types: list[str]) -> str:
    quoted = desktop_quote(executable)
    return "\n".join([
        "[Desktop Entry]",
        "Type=Application",
        "Name=File Type Chooser",
        "GenericName=Choose an Application",
        "Comment=Inspect a file and choose the application that opens it",
        "Comment[en_GB]=Inspect a file and choose the application that opens it",
        f"Exec={quoted} handle %f",
        f"TryExec={quoted}",
        "Icon=" + HANDLER_ICON_NAME,
        "Terminal=false",
        "NoDisplay=true",
        "Categories=Utility;System;",
        "Keywords=file;type;mime;handler;open with;application;",
        "StartupNotify=true",
        "MimeType=" + ";".join(mime_types) + ";",
        "",
    ])


def icon_text() -> str:
    return """<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
  <defs>
    <linearGradient id="paper" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#ffffff"/>
      <stop offset="1" stop-color="#e8f1fb"/>
    </linearGradient>
  </defs>
  <rect x="4" y="4" width="120" height="120" rx="22" fill="#3584e4"/>
  <path d="M34 22h40l22 22v50a8 8 0 0 1-8 8H34a8 8 0 0 1-8-8V30a8 8 0 0 1 8-8z" fill="url(#paper)"/>
  <path d="M74 22l22 22H80a6 6 0 0 1-6-6z" fill="#9fc3ec"/>
  <circle cx="82" cy="82" r="18" fill="#1c71d8" stroke="#ffffff" stroke-width="5"/>
  <path d="M95 95l12 12" stroke="#ffffff" stroke-width="7" stroke-linecap="round"/>
  <path d="M76 76a6 6 0 1 1 12 0c0 4-6 5-6 9" fill="none" stroke="#ffffff" stroke-width="4" stroke-linecap="round"/>
  <circle cx="82" cy="91" r="2.5" fill="#ffffff"/>
</svg>
"""


def write_text_atomic(path: Path, text: str, mode: int = 0o644) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.tmp-{os.getpid()}")
    temporary.write_text(text, encoding="utf-8")
    os.chmod(temporary, mode)
    os.replace(temporary, path)


def read_manifest() -> dict[str, object] | None:
    path = paths.handler_manifest_path()
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None


def backup_file(path: Path, directory: Path) -> str:
    if not path.is_file():
        return ""
    directory.mkdir(parents=True, exist_ok=True)
    target = directory / path.name
    suffix = 1
    while target.exists():
        target = directory / f"{path.name}.{suffix}"
        suffix += 1
    shutil.copy2(path, target)
    return str(target)


def update_desktop_database(directory: Path | None = None) -> list[str]:
    command = shutil.which("update-desktop-database")
    if command is None:
        return []
    target = directory or (paths.data_home() / "applications")
    if not target.is_dir():
        return []
    try:
        result = subprocess.run([command, str(target)], capture_output=True, text=True,
                                timeout=60, check=False)
    except (OSError, subprocess.TimeoutExpired):
        return [command, str(target)]
    return [command, str(target)] if result.returncode == 0 else []


class MimeAppsEditor:
    """Line-preserving editor for ``[Default Applications]`` in mimeapps.list."""

    def __init__(self, path: Path | None = None) -> None:
        self.path = path or paths.writable_mimeapps_path()
        self.original = ""
        self.lines: list[str] = []
        self._load()

    def _load(self) -> None:
        try:
            self.original = self.path.read_text(encoding="utf-8")
        except OSError:
            self.original = ""
        self.lines = self.original.splitlines()

    def get(self, mime: str) -> str:
        mime = normalize_mime(mime)
        for line in self._section_lines(DEFAULT_APPLICATIONS):
            if line.strip().startswith(f"{mime}="):
                value = line.split("=", 1)[1]
                return next((item for item in value.split(";") if item), "")
        return ""

    def _section_bounds(self, section: str) -> tuple[int, int] | None:
        start = None
        for index, line in enumerate(self.lines):
            stripped = line.strip()
            if stripped == f"[{section}]":
                start = index
                break
        if start is None:
            return None
        end = len(self.lines)
        for index in range(1 + start, len(self.lines)):
            if self.lines[index].strip().startswith("[") and self.lines[index].strip().endswith("]"):
                end = index
                break
        return start, end

    def _section_lines(self, section: str) -> list[str]:
        bounds = self._section_bounds(section)
        if bounds is None:
            return []
        start, end = bounds
        return self.lines[1 + start:end]

    def set(self, mime: str, desktop_id: str | None) -> bool:
        """Set or remove one default.  Returns True when the file changes."""
        mime = normalize_mime(mime)
        value = (desktop_id or "").strip()
        line_new = f"{mime}={value};" if value else None
        bounds = self._section_bounds(DEFAULT_APPLICATIONS)
        if bounds is None:
            if line_new is None:
                return False
            if self.lines and self.lines[-1].strip():
                self.lines.append("")
            self.lines.extend([f"[{DEFAULT_APPLICATIONS}]", line_new])
            return True
        start, end = bounds
        for index in range(1 + start, end):
            if self.lines[index].strip().startswith(f"{mime}="):
                if line_new is None:
                    del self.lines[index]
                elif self.lines[index] != line_new:
                    self.lines[index] = line_new
                else:
                    return False
                return True
        if line_new is None:
            return False
        insertion = end
        while insertion > 1 + start and not self.lines[insertion - 1].strip():
            insertion -= 1
        self.lines.insert(insertion, line_new)
        return True

    def save(self, backup_directory: Path | None = None) -> str:
        if self.lines == self.original.splitlines():
            return ""
        backup = ""
        if backup_directory is not None:
            backup = backup_file(self.path, backup_directory)
        text = "\n".join(self.lines).rstrip("\n") + "\n"
        write_text_atomic(self.path, text)
        return backup


@lru_cache(maxsize=1)
def _nautilus_bindings_available() -> bool:
    python = shutil.which("python3") or "python3"
    try:
        result = subprocess.run(
            [python, "-c",
             "import gi; gi.require_version('Nautilus', '4.0'); from gi.repository import Nautilus"],
            capture_output=True, timeout=30, check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return False
    return result.returncode == 0


def _handler_set(index: TypeIndex, app_index: ApplicationIndex) -> list[str]:
    return handler_mime_types(index)


def _is_unhandled(mime: str, app_index: ApplicationIndex) -> bool:
    candidates = [application for application in app_index.for_mime(mime, include_unavailable=False)
                  if application.desktop_id != paths.HANDLER_DESKTOP_ID]
    return not candidates


def install_handler(index: TypeIndex | None = None,
                    app_index: ApplicationIndex | None = None,
                    set_defaults: bool = True,
                    with_nautilus: bool = True,
                    dry_run: bool = False) -> InstallResult:
    refusal = _sandbox_refusal()
    if refusal:
        return InstallResult(False, notes=[refusal])
    index = index or TypeIndex.load()
    app_index = app_index or ApplicationIndex(index=index)
    executable = handler_exec_path()
    mime_types = _handler_set(index, app_index)
    desktop_path = paths.handler_desktop_path()
    icon_path = paths.handler_icon_path()
    manifest_path = paths.handler_manifest_path()
    nautilus_path = paths.nautilus_extension_path()

    manifest = read_manifest()
    already_installed = manifest is not None and desktop_path.is_file()
    previous_defaults: dict[str, str] = {}
    written: list[str] = []
    notes: list[str] = []
    commands: list[list[str]] = []
    backups_directory = manifest_path.parent / "backups"

    if manifest is not None and isinstance(manifest.get("previous_defaults"), dict):
        previous_defaults = dict(manifest["previous_defaults"])  # type: ignore[arg-type]

    defaults_to_set: dict[str, str] = {}
    previous_default_types: set[str] = set()
    if manifest is not None and isinstance(manifest.get("default_types"), list):
        previous_default_types = {item for item in manifest["default_types"] if isinstance(item, str)}
    handled_count = 0
    for mime in mime_types:
        current = app_index.default_id_for(mime)
        if mime not in previous_defaults:
            previous_defaults[mime] = current
        current_entry = app_index.entry(current) if current else None
        broken_default = bool(current) and (
            current_entry is None or not current_entry.executable_available)
        if broken_default:
            # A default that names an entry not installed leaves the file
            # unusable even when another handler exists, so it is replaced.
            defaults_to_set[mime] = paths.HANDLER_DESKTOP_ID
            notes.append(f"Replaced a broken default for {mime}: {current} is not installed.")
        elif _is_unhandled(mime, app_index):
            defaults_to_set[mime] = paths.HANDLER_DESKTOP_ID
        else:
            handled_count += 1

    if not set_defaults:
        defaults_to_set = {}

    written.append(str(desktop_path))
    written.append(str(icon_path))
    if dry_run:
        return InstallResult(
            ok=True, dry_run=True, manifest_path=str(manifest_path),
            desktop_entry=str(desktop_path), icon=str(icon_path),
            handler_mime_types=len(mime_types), defaults_set=len(defaults_to_set),
            already_handled=handled_count, notes=notes, written_files=written,
        )

    written_files: list[str] = []
    backups: dict[str, str] = {}
    if manifest is not None and isinstance(manifest.get("backups"), dict):
        backups = dict(manifest["backups"])  # type: ignore[arg-type]

    for path, text in ((desktop_path, desktop_entry_text(executable, mime_types)),
                       (icon_path, icon_text())):
        # A file this tool wrote is not a pre-existing file to preserve; only
        # the first install of an unknown file needs a backup.
        if path.is_file() and str(path) not in backups and not already_installed:
            backup = backup_file(path, backups_directory)
            if backup:
                backups[str(path)] = backup
        write_text_atomic(path, text)
        written_files.append(str(path))

    defaults_changed = 0
    mimeapps_backup = ""
    editor = MimeAppsEditor()
    for mime, desktop_id in defaults_to_set.items():
        if editor.set(mime, desktop_id):
            defaults_changed += 1
    if defaults_to_set:
        mimeapps_backup = editor.save(backups_directory)

    nautilus_written = ""
    if with_nautilus and _nautilus_bindings_available() and NAUTILUS_EXTENSION_SOURCE.is_file():
        if nautilus_path.is_file() and str(nautilus_path) not in backups and not already_installed:
            backup = backup_file(nautilus_path, backups_directory)
            if backup:
                backups[str(nautilus_path)] = backup
        write_text_atomic(nautilus_path, NAUTILUS_EXTENSION_SOURCE.read_text(encoding="utf-8"))
        written_files.append(str(nautilus_path))
        nautilus_written = str(nautilus_path)
    elif with_nautilus and not _nautilus_bindings_available():
        notes.append(
            "The Nautilus right-click extension needs the python3-nautilus package; "
            "the chooser is still registered in Open With."
        )

    manifest_document = {
        "schema": HANDLER_SCHEMA,
        "tool_version": version_string(),
        "installed_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "executable": executable,
        "handler_desktop_id": paths.HANDLER_DESKTOP_ID,
        "mime_types": len(mime_types),
        "defaults_set": len(defaults_to_set),
        "previous_defaults": previous_defaults,
        "default_types": sorted(previous_default_types | set(defaults_to_set)),
        "desktop_entry": str(desktop_path),
        "icon": str(icon_path),
        "nautilus_extension": nautilus_written,
        "mimeapps": str(editor.path),
        "mimeapps_backup": mimeapps_backup,
        "backups": backups,
        "written_files": written_files,
        "already_installed": already_installed,
    }
    write_text_atomic(manifest_path, json.dumps(manifest_document, indent=2) + "\n")
    written_files.append(str(manifest_path))
    commands.append(update_desktop_database(desktop_path.parent))

    if already_installed:
        notes.append("The handler was already installed; its files were refreshed.")
    return InstallResult(
        ok=True,
        manifest_path=str(manifest_path),
        desktop_entry=str(desktop_path),
        icon=str(icon_path),
        handler_mime_types=len(mime_types),
        defaults_set=defaults_changed,
        already_handled=handled_count,
        nautilus_extension=nautilus_written,
        notes=notes,
        written_files=written_files,
        commands=[command for command in commands if command],
    )


def uninstall_handler(dry_run: bool = False) -> UninstallResult:
    refusal = _sandbox_refusal()
    if refusal:
        return UninstallResult(False, notes=[refusal])
    manifest = read_manifest()
    if manifest is None:
        return UninstallResult(False, notes=[
            f"No handler manifest at {paths.handler_manifest_path()}; nothing to uninstall."
        ])
    desktop_path = paths.handler_desktop_path()
    icon_path = paths.handler_icon_path()
    nautilus_path = paths.nautilus_extension_path()
    previous_defaults = manifest.get("previous_defaults", {})
    if not isinstance(previous_defaults, dict):
        previous_defaults = {}
    # Only the types this install actually changed are considered.  A type
    # whose current value is no longer this handler was changed by the user
    # after the install, and is kept rather than restored.
    handler_id = paths.HANDLER_DESKTOP_ID
    changed_types = manifest.get("default_types")
    if not isinstance(changed_types, list) or not changed_types:
        changed_types = list(previous_defaults)
    restored = 0
    kept = 0
    notes: list[str] = []
    editor = MimeAppsEditor()
    for mime in changed_types:
        if not isinstance(mime, str):
            continue
        previous = previous_defaults.get(mime, "")
        if not isinstance(previous, str):
            previous = ""
        current = editor.get(mime)
        if current != handler_id:
            if current:
                kept += 1
            continue
        if editor.set(mime, previous or None):
            restored += 1
    backup_directory = paths.handler_manifest_path().parent / "backups"
    if restored and not dry_run:
        editor.save(backup_directory)

    removed: list[str] = []
    backups = manifest.get("backups", {})
    if not isinstance(backups, dict):
        backups = {}
    for path in (desktop_path, icon_path, nautilus_path):
        if not path.is_file():
            continue
        if dry_run:
            removed.append(str(path))
            continue
        path.unlink()
        removed.append(str(path))
    if not dry_run:
        for original, backup in backups.items():
            if not isinstance(original, str) or not isinstance(backup, str):
                continue
            backup_path = Path(backup)
            if backup_path.is_file() and not Path(original).exists():
                Path(original).parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(backup_path, original)
                removed.append(f"restored {original}")
        update_desktop_database(desktop_path.parent)
        manifest_path = paths.handler_manifest_path()
        if manifest_path.is_file():
            manifest_path.unlink()
        for directory in (backup_directory, backup_directory.parent,
                          icon_path.parent, nautilus_path.parent):
            try:
                directory.rmdir()
            except OSError:
                pass
    return UninstallResult(True, removed_files=removed, restored_defaults=restored,
                           kept_user_defaults=kept, notes=notes)


@dataclass
class HandlerStatus:
    installed: bool
    manifest_path: str
    desktop_entry: str
    desktop_entry_present: bool
    icon_present: bool
    handler_mime_types: int
    defaults_owned: int
    unhandled_types: int
    installed_applications: int
    nautilus_available: bool
    nautilus_installed: bool
    catalog_applications: int
    notes: list[str] = field(default_factory=list)

    def to_dict(self) -> dict[str, object]:
        return {
            "installed": self.installed,
            "manifest_path": self.manifest_path,
            "desktop_entry": self.desktop_entry,
            "desktop_entry_present": self.desktop_entry_present,
            "icon_present": self.icon_present,
            "handler_mime_types": self.handler_mime_types,
            "defaults_owned": self.defaults_owned,
            "unhandled_types": self.unhandled_types,
            "installed_applications": self.installed_applications,
            "nautilus_available": self.nautilus_available,
            "nautilus_installed": self.nautilus_installed,
            "catalog_applications": self.catalog_applications,
            "notes": list(self.notes),
        }


def handler_status(index: TypeIndex | None = None,
                   app_index: ApplicationIndex | None = None) -> HandlerStatus:
    index = index or TypeIndex.load()
    app_index = app_index or ApplicationIndex(index=index)
    manifest = read_manifest()
    desktop_path = paths.handler_desktop_path()
    icon_path = paths.handler_icon_path()
    editor = MimeAppsEditor()
    mime_types = handler_mime_types(index)
    owned = 0
    unhandled = 0
    for mime in mime_types:
        if editor.get(mime) == paths.HANDLER_DESKTOP_ID:
            owned += 1
        if _is_unhandled(mime, app_index):
            unhandled += 1
    try:
        catalog_count = len(ApplicationCatalog.load().applications)
    except Exception:
        catalog_count = 0
    notes: list[str] = []
    if manifest is None:
        notes.append("Not installed for this user.")
    elif not desktop_path.is_file():
        notes.append("A manifest exists, but the desktop entry is gone; run handler install again.")
    if not _nautilus_bindings_available():
        notes.append("python3-nautilus is not available, so the right-click extension is not active.")
    return HandlerStatus(
        installed=manifest is not None and desktop_path.is_file(),
        manifest_path=str(paths.handler_manifest_path()),
        desktop_entry=str(desktop_path),
        desktop_entry_present=desktop_path.is_file(),
        icon_present=icon_path.is_file(),
        handler_mime_types=len(mime_types),
        defaults_owned=owned,
        unhandled_types=unhandled,
        installed_applications=len(app_index.entries),
        nautilus_available=_nautilus_bindings_available(),
        nautilus_installed=paths.nautilus_extension_path().is_file(),
        catalog_applications=catalog_count,
        notes=notes,
    )

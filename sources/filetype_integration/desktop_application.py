"""Discover the applications a desktop actually has installed.

The desktop entry is the unit of installation on a freedesktop desktop: an
application package drops one into ``applications/`` and names the MIME types
it can open.  Reading those entries directly, plus the ``mimeapps.list``
defaults, answers "what can open this file here?" without starting a session.
"""

from __future__ import annotations

import os
import shlex
import shutil
import xml.etree.ElementTree as ElementTree
from dataclasses import dataclass, field
from functools import lru_cache
from pathlib import Path

from . import paths
from .mime_index import TypeIndex, normalize_mime

FILE_FIELD_CODES = ("%f", "%F", "%u", "%U")
OTHER_FIELD_CODES = ("%i", "%c", "%k", "%d", "%D", "%n", "%N", "%v", "%m")


def _unescape(value: str) -> str:
    output: list[str] = []
    index = 0
    while index < len(value):
        character = value[index]
        if character == "\\" and 1 + index < len(value):
            following = value[1 + index]
            mapping = {"s": " ", "n": "\n", "t": "\t", "r": "\r", "\\": "\\"}
            if following in mapping:
                output.append(mapping[following])
                index += 2
                continue
        output.append(character)
        index += 1
    return "".join(output)


def _localized(values: dict[str, str], key: str) -> str:
    if key in values:
        return values[key]
    for candidate, value in values.items():
        if candidate.startswith(f"{key}["):
            return value
    return ""


def parse_desktop_entry(path: Path) -> dict[str, str]:
    """Parse the ``[Desktop Entry]`` group of one desktop file."""
    values: dict[str, str] = {}
    in_group = False
    try:
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return values
    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if stripped.startswith("[") and stripped.endswith("]"):
            in_group = stripped == "[Desktop Entry]"
            continue
        if not in_group or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = _unescape(value.strip())
    return values


def executable_from_command(command: str) -> str:
    try:
        parts = shlex.split(command)
    except ValueError:
        return ""
    for part in parts:
        if part.startswith("%"):
            continue
        if part in {"env", "sh", "bash"}:
            continue
        return part
    return ""


def command_template(exec_line: str) -> list[str]:
    """Split an Exec line into an argv template with ``{file}`` placeholders."""
    without_codes = exec_line.replace("%%", "\x00PERCENT\x00")
    for code in OTHER_FIELD_CODES:
        without_codes = without_codes.replace(code, "")
    for code in FILE_FIELD_CODES:
        without_codes = without_codes.replace(code, "{file}")
    try:
        parts = shlex.split(without_codes)
    except ValueError:
        parts = without_codes.split()
    return [part.replace("\x00PERCENT\x00", "%") for part in parts]


def command_for_file(exec_line: str, path: str) -> list[str]:
    template = command_template(exec_line)
    result: list[str] = []
    for part in template:
        if "{file}" in part:
            result.append(part.replace("{file}", str(path)))
        else:
            result.append(part)
    return result


def current_desktop_names() -> set[str]:
    names: set[str] = set()
    for name in os.environ.get("XDG_CURRENT_DESKTOP", "").split(":"):
        name = name.strip().lower()
        if name:
            names.add(name)
            # GNOME-Flashback and GNOME-Classic belong to the GNOME family.
            if name.startswith("gnome"):
                names.add("gnome")
    return names


def _local_name(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


@lru_cache(maxsize=1)
def appstream_homepages() -> dict[str, str]:
    """Map an application id to the homepage AppStream records for it."""
    homepages: dict[str, str] = {}
    for directory in paths.metainfo_dirs():
        if not directory.is_dir():
            continue
        for path in sorted(directory.glob("*.xml")):
            try:
                tree = ElementTree.parse(path)
            except (ElementTree.ParseError, OSError):
                continue
            identifier = ""
            homepage = ""
            for element in tree.getroot().iter():
                name = _local_name(element.tag)
                if name == "id" and not identifier:
                    identifier = (element.text or "").strip()
                elif name == "url" and element.get("type") == "homepage" and not homepage:
                    homepage = (element.text or "").strip()
            if not homepage:
                continue
            for key in (identifier, identifier.removesuffix(".desktop")):
                if key:
                    homepages.setdefault(key, homepage)
    return homepages


def application_homepage(application: InstalledApplication) -> str:
    """The project page AppStream records for this desktop entry, if any."""
    homepages = appstream_homepages()
    for key in (application.desktop_id,
                application.desktop_id.removesuffix(".desktop"),
                application.flatpak_id):
        if key and key in homepages:
            return homepages[key]
    return ""


def entry_is_visible(values: dict[str, str]) -> bool:
    if values.get("Hidden", "false").lower() == "true":
        return False
    if values.get("NoDisplay", "false").lower() == "true":
        return False
    desktop = current_desktop_names()
    only = {item.strip().lower() for item in values.get("OnlyShowIn", "").split(";") if item.strip()}
    if only and desktop and not (only & desktop):
        return False
    not_show = {item.strip().lower() for item in values.get("NotShowIn", "").split(";") if item.strip()}
    if not_show and desktop and (not_show & desktop):
        return False
    return True


@dataclass
class InstalledApplication:
    desktop_id: str
    name: str
    comment: str = ""
    generic_name: str = ""
    icon: str = ""
    executable: str = ""
    exec_line: str = ""
    terminal: bool = False
    mime_types: list[str] = field(default_factory=list)
    categories: list[str] = field(default_factory=list)
    no_display: bool = False
    hidden: bool = False
    source_path: str = ""
    flatpak_id: str = ""
    executable_available: bool = True
    match_mime: str = ""
    match_kind: str = ""

    @property
    def purpose(self) -> str:
        return self.comment or self.generic_name or f"Application {self.name}"

    @property
    def visibility(self) -> str:
        if self.hidden:
            return "hidden"
        if self.no_display:
            return "background"
        return "visible"

    def command_for(self, path: str) -> list[str]:
        return command_for_file(self.exec_line, path)

    def to_dict(self) -> dict[str, object]:
        return {
            "kind": "installed",
            "desktop_id": self.desktop_id,
            "name": self.name,
            "purpose": self.purpose,
            "icon": self.icon,
            "executable": self.executable,
            "terminal": self.terminal,
            "mime_types": list(self.mime_types),
            "categories": list(self.categories),
            "visibility": self.visibility,
            "source_path": self.source_path,
            "flatpak_id": self.flatpak_id,
            "executable_available": self.executable_available,
            "match_mime": self.match_mime,
            "match_kind": self.match_kind,
            "installed": True,
        }


def _desktop_id_for(path: Path, root: Path) -> str:
    try:
        relative = path.relative_to(root)
    except ValueError:
        relative = Path(path.name)
    # The desktop file id keeps the .desktop suffix: that is the identifier
    # mimeapps.list and GIO use ("org.gnome.TextEditor.desktop").
    return str(relative).replace(os.sep, "-")


def discover_desktop_entries(data_dirs: list[Path] | None = None,
                             data_home: Path | None = None) -> dict[str, InstalledApplication]:
    """Read every desktop entry visible to this user, one per desktop id."""
    applications_dirs: list[Path] = []
    if data_home is not None or data_dirs is not None:
        home = data_home or paths.data_home()
        directories = data_dirs if data_dirs is not None else paths.data_dirs()
        applications_dirs = [home / "applications"] + [directory / "applications" for directory in directories]
    else:
        applications_dirs = paths.applications_dirs()

    entries: dict[str, InstalledApplication] = {}
    for root in applications_dirs:
        if not root.is_dir():
            continue
        for path in sorted(root.rglob("*.desktop")):
            desktop_id = _desktop_id_for(path, root)
            # The chooser is an integration, not one of the choices it offers.
            if desktop_id == paths.HANDLER_DESKTOP_ID:
                continue
            if desktop_id in entries:
                continue
            values = parse_desktop_entry(path)
            if values.get("Type", "Application") != "Application":
                continue
            name = _localized(values, "Name")
            if not name:
                continue
            exec_line = values.get("Exec", "")
            executable = values.get("TryExec", "") or executable_from_command(exec_line)
            executable_available = True
            if executable:
                if os.path.isabs(executable):
                    executable_available = os.access(executable, os.X_OK)
                else:
                    executable_available = shutil.which(executable) is not None
            mime_types = [normalize_mime(item) for item in values.get("MimeType", "").split(";")
                          if normalize_mime(item)]
            categories = [item for item in values.get("Categories", "").split(";") if item]
            entries[desktop_id] = InstalledApplication(
                desktop_id=desktop_id,
                name=name,
                comment=_localized(values, "Comment"),
                generic_name=_localized(values, "GenericName"),
                icon=values.get("Icon", ""),
                executable=executable,
                exec_line=exec_line,
                terminal=values.get("Terminal", "false").lower() == "true",
                mime_types=mime_types,
                categories=categories,
                no_display=values.get("NoDisplay", "false").lower() == "true",
                hidden=values.get("Hidden", "false").lower() == "true",
                source_path=str(path),
                flatpak_id=values.get("X-Flatpak", ""),
                executable_available=executable_available,
            )
    return entries


def read_mimeapps(path: Path) -> dict[str, dict[str, list[str]]]:
    sections: dict[str, dict[str, list[str]]] = {}
    try:
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return sections
    current = ""
    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if stripped.startswith("[") and stripped.endswith("]"):
            current = stripped[1:-1].strip()
            sections.setdefault(current, {})
            continue
        if not current or "=" not in stripped:
            continue
        key, value = stripped.split("=", 1)
        key = normalize_mime(key)
        if not key:
            continue
        applications = [item for item in value.split(";") if item]
        sections[current][key] = applications
    return sections


@dataclass
class MimeDefaults:
    defaults: dict[str, str] = field(default_factory=dict)
    added: dict[str, list[str]] = field(default_factory=dict)
    removed: dict[str, list[str]] = field(default_factory=dict)
    sources: list[str] = field(default_factory=list)

    def default_for(self, mime: str) -> str:
        return self.defaults.get(normalize_mime(mime), "")


def read_mime_defaults(files: list[Path] | None = None) -> MimeDefaults:
    """Merge the mimeapps files in precedence order (first wins)."""
    result = MimeDefaults()
    for path in (files if files is not None else paths.mimeapps_files()):
        sections = read_mimeapps(path)
        if not sections:
            continue
        result.sources.append(str(path))
        for mime, applications in sections.get("Default Applications", {}).items():
            if mime not in result.defaults and applications:
                result.defaults[mime] = applications[0]
        for mime, applications in sections.get("Added Associations", {}).items():
            existing = result.added.setdefault(mime, [])
            for application in applications:
                if application not in existing:
                    existing.append(application)
        for mime, applications in sections.get("Removed Associations", {}).items():
            existing = result.removed.setdefault(mime, [])
            for application in applications:
                if application not in existing:
                    existing.append(application)
    return result


def gio_default_for_mime(mime: str) -> str:
    """Ask GIO for the default, as the running desktop would resolve it."""
    if os.environ.get("FILETYPE_INTEGRATION_NO_GIO") == "1":
        return ""
    try:
        from gi.repository import Gio  # type: ignore
    except (ImportError, ValueError):
        return ""
    try:
        application = Gio.AppInfo.get_default_for_type(normalize_mime(mime), False)
    except Exception:
        return ""
    if application is None:
        return ""
    try:
        return application.get_id() or ""
    except Exception:
        return ""


class ApplicationIndex:
    """Installed applications and the defaults for every MIME type."""

    def __init__(self, index: TypeIndex | None = None,
                 entries: dict[str, InstalledApplication] | None = None,
                 defaults: MimeDefaults | None = None,
                 use_gio: bool = True) -> None:
        self.types = index or TypeIndex.load()
        self.entries = entries if entries is not None else discover_desktop_entries()
        self.defaults = defaults if defaults is not None else read_mime_defaults()
        self.use_gio = use_gio
        self._by_mime: dict[str, list[str]] = {}
        for desktop_id, application in self.entries.items():
            for mime in application.mime_types:
                self._by_mime.setdefault(mime, []).append(desktop_id)
        self._gio_defaults: dict[str, str] = {}

    def entry(self, desktop_id: str) -> InstalledApplication | None:
        return self.entries.get(desktop_id)

    def default_for(self, mime: str) -> InstalledApplication | None:
        mime = normalize_mime(mime)
        candidates = [mime]
        for alias in self.types.aliases_for(mime):
            if alias not in candidates:
                candidates.append(alias)
        desktop_id = ""
        for candidate in candidates:
            desktop_id = self.defaults.default_for(candidate)
            if desktop_id:
                break
        if not desktop_id and self.use_gio:
            if mime not in self._gio_defaults:
                self._gio_defaults[mime] = gio_default_for_mime(mime)
            desktop_id = self._gio_defaults[mime]
        if not desktop_id:
            return None
        application = self.entries.get(desktop_id)
        if application is not None:
            return application
        # GIO may name an entry from a directory this index did not read.
        return None

    def default_id_for(self, mime: str) -> str:
        application = self.default_for(mime)
        if application is not None:
            return application.desktop_id
        return self.defaults.default_for(mime) or ""

    def _match_candidates(self, mime: str) -> list[tuple[str, str]]:
        mime = normalize_mime(mime)
        candidates: list[tuple[str, str]] = []
        for family_mime in self.types.handler_family(mime):
            for desktop_id in self._by_mime.get(family_mime, ()):
                candidates.append((desktop_id, family_mime))
        return candidates

    def for_mime(self, mime: str, include_unavailable: bool = True) -> list[InstalledApplication]:
        """Installed applications that can open a type, best match first."""
        mime = normalize_mime(mime)
        default_id = self.default_id_for(mime)
        seen: set[str] = set()
        result: list[InstalledApplication] = []
        for desktop_id, family_mime in self._match_candidates(mime):
            if desktop_id == paths.HANDLER_DESKTOP_ID:
                continue
            if desktop_id in seen:
                continue
            seen.add(desktop_id)
            application = self.entries.get(desktop_id)
            if application is None:
                continue
            if not include_unavailable and not application.executable_available:
                continue
            application = _copy_application(application)
            application.match_mime = family_mime
            application.match_kind = "exact" if family_mime == mime else "ancestor"
            if desktop_id == default_id:
                application.match_kind = "default"
            result.append(application)
        result.sort(key=lambda app: (
            app.match_kind != "default",
            app.match_kind != "exact",
            not app.executable_available,
            app.name.lower(),
        ))
        return result

    def registered_for(self, mime: str) -> list[InstalledApplication]:
        return self.for_mime(mime)

    def has_default(self, mime: str) -> bool:
        return self.default_for(mime) is not None

    def has_any_handler(self, mime: str) -> bool:
        return bool(self.for_mime(mime, include_unavailable=False))

    def unhandled_types(self) -> list[str]:
        result: list[str] = []
        for mime in sorted(self.types.types):
            if not self.has_any_handler(mime):
                result.append(mime)
        return result

    def visible_applications(self) -> list[InstalledApplication]:
        return sorted(
            (application for application in self.entries.values()
             if application.desktop_id != paths.HANDLER_DESKTOP_ID
             and entry_is_visible({"NoDisplay": "true" if application.no_display else "false",
                                   "Hidden": "true" if application.hidden else "false"})),
            key=lambda application: application.name.lower(),
        )

    def installed_catalog_ids(self) -> set[str]:
        """Desktop ids and Flatpak ids that are present on this machine."""
        ids = set(self.entries)
        for application in self.entries.values():
            if application.flatpak_id:
                ids.add(application.flatpak_id)
        return ids


def _copy_application(application: InstalledApplication) -> InstalledApplication:
    return InstalledApplication(
        desktop_id=application.desktop_id,
        name=application.name,
        comment=application.comment,
        generic_name=application.generic_name,
        icon=application.icon,
        executable=application.executable,
        exec_line=application.exec_line,
        terminal=application.terminal,
        mime_types=list(application.mime_types),
        categories=list(application.categories),
        no_display=application.no_display,
        hidden=application.hidden,
        source_path=application.source_path,
        flatpak_id=application.flatpak_id,
        executable_available=application.executable_available,
        match_mime=application.match_mime,
        match_kind=application.match_kind,
    )


def discover_installed(index: TypeIndex | None = None) -> ApplicationIndex:
    return ApplicationIndex(index=index)

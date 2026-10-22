"""The curated catalog of applications, and the ranking that uses it.

Installed applications come from the desktop.  The catalog adds the
applications that are not installed but are worth offering, with a purpose,
an editorial maturity and popularity estimate, and install hints.  Ranking
keeps installed applications first, then orders the suggestions by how
specifically they handle the file and how useful they are for that kind.
"""

from __future__ import annotations

import json
import os
import shutil
from dataclasses import dataclass, field
from pathlib import Path

from .desktop_application import ApplicationIndex, InstalledApplication
from .file_identifier import Identification
from .mime_index import TypeIndex, category_label, normalize_mime

CATALOG_SCHEMA = 1
DATA_DIRECTORY = Path(__file__).with_name("data")
DEFAULT_CATALOG_PATH = DATA_DIRECTORY / "application-catalog.json"

MATURITY_WEIGHT = {
    "mature": 18,
    "stable": 14,
    "beta": 6,
    "experimental": 2,
    "legacy": 4,
    "unknown": 8,
}

USEFULNESS_WEIGHT = {
    "primary": 24,
    "general": 16,
    "specialized": 12,
    "companion": 8,
    "fallback": 2,
    "installed": 0,
}

KIND_WEIGHT = {"gui": 4, "cli": 1}


@dataclass
class CatalogApplication:
    id: str
    name: str
    purpose: str
    kind: str
    maturity: str
    popularity: int
    usefulness: str
    handles: dict[str, list[str]]
    install: dict[str, str]
    desktop_ids: list[str] = field(default_factory=list)
    binary: str = ""
    notes: str = ""

    @property
    def mime_patterns(self) -> list[str]:
        return list(self.handles.get("mime", []))

    @property
    def extensions(self) -> list[str]:
        return [extension.lower().lstrip(".") for extension in self.handles.get("extensions", [])]

    @property
    def categories(self) -> list[str]:
        return list(self.handles.get("categories", []))

    def to_dict(self) -> dict[str, object]:
        return {
            "id": self.id,
            "name": self.name,
            "purpose": self.purpose,
            "kind": self.kind,
            "maturity": self.maturity,
            "popularity": self.popularity,
            "usefulness": self.usefulness,
            "handles": self.handles,
            "install": self.install,
            "desktop_ids": self.desktop_ids,
            "binary": self.binary,
            "notes": self.notes,
        }


@dataclass
class CatalogMatch:
    application: CatalogApplication
    match_score: int
    reasons: list[str]

    def to_dict(self) -> dict[str, object]:
        return {
            "application": self.application.to_dict(),
            "match_score": self.match_score,
            "reasons": self.reasons,
        }


class CatalogError(ValueError):
    """The catalog is malformed; the message names the offending entry."""


class ApplicationCatalog:
    def __init__(self, applications: list[CatalogApplication],
                 path: str = "", schema: int = CATALOG_SCHEMA) -> None:
        self.applications = applications
        self.path = path
        self.schema = schema
        self.by_id = {application.id: application for application in applications}

    @classmethod
    def load(cls, path: Path | str | None = None) -> "ApplicationCatalog":
        override = os.environ.get("FILETYPE_CATALOG_FILE")
        catalog_path = Path(path) if path is not None else (
            Path(override) if override else DEFAULT_CATALOG_PATH)
        try:
            raw = json.loads(catalog_path.read_text(encoding="utf-8"))
        except OSError as error:
            raise CatalogError(f"cannot read catalog {catalog_path}: {error}") from error
        except json.JSONDecodeError as error:
            raise CatalogError(f"catalog {catalog_path} is not valid JSON: {error}") from error
        return cls.from_document(raw, str(catalog_path))

    @classmethod
    def from_document(cls, raw: dict[str, object], path: str = "") -> "ApplicationCatalog":
        if not isinstance(raw, dict):
            raise CatalogError("the catalog root must be an object")
        schema = raw.get("schema")
        if schema != CATALOG_SCHEMA:
            raise CatalogError(f"unsupported catalog schema: {schema!r}")
        entries = raw.get("applications")
        if not isinstance(entries, list):
            raise CatalogError("the catalog has no applications list")
        applications: list[CatalogApplication] = []
        seen: set[str] = set()
        for index, entry in enumerate(entries):
            application = _parse_application(entry, index)
            if application.id in seen:
                raise CatalogError(f"duplicate application id: {application.id}")
            seen.add(application.id)
            applications.append(application)
        return cls(applications, path=path, schema=schema)

    def get(self, identifier: str) -> CatalogApplication | None:
        return self.by_id.get(identifier)

    def search(self, query: str) -> list[CatalogApplication]:
        query = query.strip().lower()
        if not query:
            return list(self.applications)
        results: list[CatalogApplication] = []
        for application in self.applications:
            haystack = " ".join([
                application.id,
                application.name,
                application.purpose,
                " ".join(application.mime_patterns),
                " ".join(application.extensions),
                " ".join(application.categories),
            ]).lower()
            if query in haystack:
                results.append(application)
        return results

    def matches(self, mime: str, extension: str = "", category: str = "",
                index: TypeIndex | None = None,
                installable_only: bool = False) -> list[CatalogMatch]:
        mime = normalize_mime(mime)
        extension = extension.lower().lstrip(".")
        category = category.lower()
        family = set(index.handler_family(mime)) if index is not None else {mime}
        matches: list[CatalogMatch] = []
        for application in self.applications:
            score = 0
            reasons: list[str] = []
            for pattern in application.mime_patterns:
                pattern = normalize_mime(pattern)
                if pattern == mime:
                    score = max(score, 130)
                    reasons.append(f"Handles {mime} directly")
                elif pattern.endswith("/*") and mime.startswith(pattern[:-1]):
                    score = max(score, 110)
                    reasons.append(f"Handles the {pattern[:-1]} family")
                elif pattern in family:
                    score = max(score, 95)
                    reasons.append(f"Handles the related type {pattern}")
            if extension and extension in application.extensions:
                score = max(score, 90)
                reasons.append(f"Handles .{extension} files")
            elif extension:
                for candidate in application.extensions:
                    if extension.endswith(f".{candidate}") or candidate.endswith(f".{extension}"):
                        score = max(score, 85)
                        reasons.append(f"Handles the .{candidate} family")
                        break
            if category and category in application.categories:
                score = max(score, 45)
                reasons.append(f"A {category_label(category).lower()} application")
            if score == 0:
                continue
            if installable_only and not application.install:
                continue
            matches.append(CatalogMatch(application=application, match_score=score,
                                        reasons=reasons))
        matches.sort(key=lambda match: (
            -match.match_score,
            -USEFULNESS_WEIGHT.get(match.application.usefulness, 0),
            -match.application.popularity,
            match.application.name.lower(),
        ))
        return matches

    def stats(self) -> dict[str, object]:
        mime_patterns = {pattern for application in self.applications
                         for pattern in application.mime_patterns}
        extensions = {extension for application in self.applications
                      for extension in application.extensions}
        categories: dict[str, int] = {}
        for application in self.applications:
            for category in application.categories:
                categories[category] = categories.get(category, 0) + 1
        return {
            "applications": len(self.applications),
            "mime_patterns": len(mime_patterns),
            "extensions": len(extensions),
            "categories": dict(sorted(categories.items())),
            "path": self.path,
        }


def _parse_application(raw: object, index: int) -> CatalogApplication:
    label = f"applications[{index}]"
    if not isinstance(raw, dict):
        raise CatalogError(f"{label} must be an object")
    identifier = _require_string(raw, "id", label)
    name = _require_string(raw, "name", label)
    purpose = _require_string(raw, "purpose", label)
    kind = raw.get("kind", "gui")
    if kind not in KIND_WEIGHT:
        raise CatalogError(f"{label}: kind must be gui or cli")
    maturity = raw.get("maturity", "unknown")
    if maturity not in MATURITY_WEIGHT:
        raise CatalogError(f"{label}: unknown maturity {maturity!r}")
    usefulness = raw.get("usefulness", "general")
    if usefulness not in USEFULNESS_WEIGHT:
        raise CatalogError(f"{label}: unknown usefulness {usefulness!r}")
    popularity = raw.get("popularity", 0)
    if not isinstance(popularity, int) or not 0 <= popularity <= 100:
        raise CatalogError(f"{label}: popularity must be an integer from 0 to 100")
    handles = raw.get("handles")
    if not isinstance(handles, dict) or not handles:
        raise CatalogError(f"{label}: handles must describe at least one MIME type, extension, or category")
    parsed_handles: dict[str, list[str]] = {}
    for key in ("mime", "extensions", "categories"):
        value = handles.get(key, [])
        if not isinstance(value, list) or not all(isinstance(item, str) and item for item in value):
            raise CatalogError(f"{label}: handles.{key} must be a list of strings")
        parsed_handles[key] = list(value)
    install = raw.get("install", {})
    if not isinstance(install, dict) or not all(isinstance(key, str) and isinstance(value, str)
                                                for key, value in install.items()):
        raise CatalogError(f"{label}: install must map a method to a package or URL")
    desktop_ids = raw.get("desktop_ids", [])
    if not isinstance(desktop_ids, list) or not all(isinstance(item, str) for item in desktop_ids):
        raise CatalogError(f"{label}: desktop_ids must be a list of strings")
    binary = raw.get("binary", "")
    notes = raw.get("notes", "")
    if not isinstance(binary, str) or not isinstance(notes, str):
        raise CatalogError(f"{label}: binary and notes must be strings")
    return CatalogApplication(
        id=identifier,
        name=name,
        purpose=purpose,
        kind=kind,
        maturity=maturity,
        popularity=popularity,
        usefulness=usefulness,
        handles=parsed_handles,
        install=install,
        desktop_ids=desktop_ids,
        binary=binary,
        notes=notes,
    )


def _require_string(raw: dict[str, object], key: str, label: str) -> str:
    value = raw.get(key)
    if not isinstance(value, str) or not value.strip():
        raise CatalogError(f"{label}: {key} must be a non-empty string")
    return value.strip()


@dataclass
class RankedApplication:
    identifier: str
    name: str
    purpose: str
    kind: str
    maturity: str
    popularity: int | None
    usefulness: str
    installed: bool
    usable: bool
    install: dict[str, str]
    reasons: list[str]
    score: float
    source: str
    desktop: InstalledApplication | None = None
    catalog: CatalogApplication | None = None
    match_kind: str = ""
    match_mime: str = ""

    @property
    def desktop_id(self) -> str:
        return self.desktop.desktop_id if self.desktop is not None else ""

    @property
    def terminal(self) -> bool:
        return bool(self.desktop and self.desktop.terminal)

    def to_dict(self) -> dict[str, object]:
        return {
            "id": self.identifier,
            "name": self.name,
            "purpose": self.purpose,
            "kind": self.kind,
            "maturity": self.maturity,
            "popularity": self.popularity,
            "usefulness": self.usefulness,
            "installed": self.installed,
            "usable": self.usable,
            "source": self.source,
            "desktop_id": self.desktop_id,
            "terminal": self.terminal,
            "match_kind": self.match_kind,
            "match_mime": self.match_mime,
            "score": round(self.score, 1),
            "reasons": list(self.reasons),
            "install": dict(self.install),
            "notes": self.catalog.notes if self.catalog is not None else "",
        }


@dataclass
class Recommendation:
    identification: Identification
    installed: list[RankedApplication]
    available: list[RankedApplication]
    default: RankedApplication | None = None
    unhandled: bool = False
    notes: list[str] = field(default_factory=list)

    @property
    def all(self) -> list[RankedApplication]:
        return [*self.installed, *self.available]

    def to_dict(self) -> dict[str, object]:
        return {
            "installed": [application.to_dict() for application in self.installed],
            "available": [application.to_dict() for application in self.available],
            "default": self.default.to_dict() if self.default is not None else None,
            "unhandled": self.unhandled,
            "notes": list(self.notes),
        }


def install_commands(application: CatalogApplication) -> list[dict[str, str]]:
    commands: list[dict[str, str]] = []
    if "apt" in application.install:
        commands.append({"method": "apt", "package": application.install["apt"],
                         "command": f"sudo apt install {application.install['apt']}"})
    if "flatpak" in application.install:
        commands.append({"method": "flatpak", "package": application.install["flatpak"],
                         "command": f"flatpak install flathub {application.install['flatpak']}"})
    if "snap" in application.install:
        commands.append({"method": "snap", "package": application.install["snap"],
                         "command": f"sudo snap install {application.install['snap']}"})
    if "url" in application.install:
        commands.append({"method": "download", "package": application.install["url"],
                         "command": f"Open {application.install['url']}"})
    return commands


def preferred_install(application: CatalogApplication) -> dict[str, str] | None:
    commands = install_commands(application)
    if not commands:
        return None
    available = {
        "apt": shutil.which("apt-get") is not None,
        "flatpak": shutil.which("flatpak") is not None,
        "snap": shutil.which("snap") is not None,
    }
    for method in ("apt", "flatpak", "snap"):
        if available.get(method):
            for command in commands:
                if command["method"] == method:
                    return command
    return commands[0]


def _catalog_is_installed(application: CatalogApplication,
                          installed: ApplicationIndex) -> tuple[bool, InstalledApplication | None]:
    for desktop_id in application.desktop_ids:
        entry = installed.entry(desktop_id)
        if entry is not None:
            return True, entry
    if application.binary and shutil.which(application.binary):
        return True, None
    return False, None


def _installed_application(application: InstalledApplication,
                           catalog: ApplicationCatalog | None,
                           identification_category: str = "") -> RankedApplication:
    catalog_entry = None
    if catalog is not None:
        for candidate in catalog.applications:
            if (application.desktop_id in candidate.desktop_ids
                    or (candidate.binary and candidate.binary == application.executable)
                    or candidate.name.casefold() == application.name.casefold()):
                catalog_entry = candidate
                break
    maturity = catalog_entry.maturity if catalog_entry is not None else "unknown"
    popularity = catalog_entry.popularity if catalog_entry is not None else None
    usefulness = catalog_entry.usefulness if catalog_entry is not None else "installed"
    purpose = (catalog_entry.purpose if catalog_entry is not None and catalog_entry.purpose
               else application.purpose)
    score = 1000.0
    reasons: list[str] = []
    if application.match_kind == "default":
        score += 300
        reasons.append("The desktop's default application")
    elif application.match_kind == "exact":
        score += 220
        reasons.append(f"Registers {application.match_mime}")
    else:
        score += 80
        reasons.append(f"Handles the related type {application.match_mime}")
    if not application.executable_available:
        score -= 250
        reasons.append("Its launcher is present but its program was not found")
    score += USEFULNESS_WEIGHT.get(usefulness, 0)
    if catalog_entry is not None:
        if application.match_mime in catalog_entry.mime_patterns:
            score += 60
            reasons.append(f"Named as a {application.match_mime} handler by the catalog")
        if identification_category and identification_category in catalog_entry.categories:
            score += 20
    reasons.append("Installed on this machine")
    return RankedApplication(
        identifier=application.desktop_id,
        name=application.name,
        purpose=purpose,
        kind="gui",
        maturity=maturity,
        popularity=popularity,
        usefulness=usefulness,
        installed=True,
        usable=application.executable_available,
        install=dict(catalog_entry.install) if catalog_entry is not None else {},
        reasons=reasons,
        score=score,
        source="installed",
        desktop=application,
        catalog=catalog_entry,
        match_kind=application.match_kind,
        match_mime=application.match_mime,
    )


def _available_application(match: CatalogMatch, installed: bool,
                           desktop: InstalledApplication | None) -> RankedApplication:
    application = match.application
    score = 100.0 + match.match_score + USEFULNESS_WEIGHT.get(application.usefulness, 0)
    score += MATURITY_WEIGHT.get(application.maturity, 0)
    score += application.popularity * 0.35
    score += KIND_WEIGHT.get(application.kind, 0)
    if installed:
        score += 700
    reasons = list(match.reasons)
    if installed:
        reasons.append("Installed, but not registered as a handler for this type")
    else:
        reasons.append("Not installed")
    if application.kind == "cli":
        reasons.append("A command-line tool")
    return RankedApplication(
        identifier=application.id,
        name=application.name,
        purpose=application.purpose,
        kind=application.kind,
        maturity=application.maturity,
        popularity=application.popularity,
        usefulness=application.usefulness,
        installed=installed,
        usable=installed,
        install=dict(application.install),
        reasons=reasons,
        score=score,
        source="catalog",
        desktop=desktop,
        catalog=application,
        match_kind="catalog",
        match_mime="",
    )


def recommend(identification: Identification, installed: ApplicationIndex,
              catalog: ApplicationCatalog | None = None,
              index: TypeIndex | None = None) -> Recommendation:
    catalog = catalog or ApplicationCatalog.load()
    index = index or installed.types
    installed_apps = installed.for_mime(identification.mime)
    ranked_installed: list[RankedApplication] = []
    installed_ids: set[str] = set()
    installed_names: set[str] = set()
    for application in installed_apps:
        ranked = _installed_application(application, catalog, identification.category)
        ranked_installed.append(ranked)
        installed_ids.add(application.desktop_id)
        installed_names.add(application.name.casefold())
    ranked_installed.sort(key=lambda application: (
        not application.usable,
        -application.score,
        application.name.lower(),
    ))
    unique_installed: list[RankedApplication] = []
    unique_names: set[str] = set()
    for application in ranked_installed:
        name_key = application.name.casefold()
        if name_key in unique_names:
            continue
        unique_names.add(name_key)
        unique_installed.append(application)
    ranked_installed = unique_installed

    default_ranked = next((application for application in ranked_installed
                           if application.match_kind == "default"), None)
    if default_ranked is None:
        default_id = installed.default_id_for(identification.mime)
        default_ranked = next((application for application in ranked_installed
                               if application.desktop_id == default_id), None)
    default_note = ""
    if default_ranked is not None and not default_ranked.usable:
        default_note = (
            f"The desktop default, {default_ranked.name}, is registered but its "
            "program was not found."
        )
        default_ranked = None

    extension = identification.extension.suffix or ""
    matches = catalog.matches(identification.mime, extension=extension,
                              category=identification.category, index=index)
    available: list[RankedApplication] = []
    seen_available: set[str] = set()
    for match in matches:
        application = match.application
        if application.id in seen_available:
            continue
        if application.name.casefold() in installed_names:
            continue
        is_installed, desktop = _catalog_is_installed(application, installed)
        # An installed desktop entry already listed is not repeated in the
        # suggestion list; a catalog entry without a desktop id may still be
        # useful as a CLI suggestion.
        if is_installed and desktop is not None:
            if desktop.desktop_id in installed_ids:
                continue
            # The program is installed and has a desktop entry, but it does
            # not register this type.  It still belongs in the installed
            # list: the user may deliberately ask it to open the file.
            installed_ids.add(desktop.desktop_id)
            ranked = _available_application(match, True, desktop)
            ranked.reasons.insert(0, "Installed, but not registered for this type")
            ranked_installed.append(ranked)
            continue
        seen_available.add(application.id)
        ranked = _available_application(match, is_installed, desktop)
        if is_installed and desktop is None:
            ranked.usable = False
            ranked.reasons.append("Command-line tool; run it in a terminal")
        available.append(ranked)
    available.sort(key=lambda application: (
        not application.installed,
        -application.score,
        application.name.lower(),
    ))

    usable_installed = [application for application in ranked_installed if application.usable]
    unhandled = not usable_installed
    notes: list[str] = []
    if default_note:
        notes.append(default_note)
    if unhandled and not ranked_installed:
        notes.append(
            f"No application on this machine is registered for {identification.mime}."
        )
    elif unhandled:
        notes.append(
            "Handlers are registered for this type, but none of their programs were found."
        )
    if identification.conflict is not None:
        notes.append(str(identification.conflict.get("explanation", "")))
    return Recommendation(
        identification=identification,
        installed=ranked_installed,
        available=available,
        default=default_ranked,
        unhandled=unhandled,
        notes=notes,
    )

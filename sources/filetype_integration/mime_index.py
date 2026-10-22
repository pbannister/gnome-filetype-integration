"""The system MIME database as an index of names, globs, and categories.

The index is built from the same data the desktop uses: the shared-mime-info
``globs2``, ``aliases``, ``subclasses``, and package XML files, plus the
``mime.types`` files.  Reading those files directly keeps identification
independent of a running desktop session and makes the whole index testable
against a fixture tree.
"""

from __future__ import annotations

import fnmatch
import os
import re
import xml.etree.ElementTree as ElementTree
from dataclasses import dataclass, field
from pathlib import Path

from . import paths

MIME_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9!#$&^_.+-]*/[A-Za-z0-9][A-Za-z0-9!#$&^_.+-]*$")

# libmagic calls the same language text/x-php while the shared MIME database
# uses application/x-php.  They are one type, not two.
BUILTIN_ALIASES = {
    "text/x-php": "application/x-php",
    "application/x-httpd-php": "application/x-php",
}

GENERIC_MIME_TYPES = frozenset(
    {
        "application/octet-stream",
        "application/x-empty",
        "application/zip",
        "application/x-tar",
        "application/gzip",
        "text/plain",
        "inode/x-empty",
    }
)

# Ancestors broad enough to be useful when looking for a handler.  A specific
# format's odd ancestry (a Python script is an "executable") is not used.
HANDLER_PARENTS = frozenset(
    {
        "text/plain",
        "application/octet-stream",
        "application/zip",
        "application/x-tar",
        "application/gzip",
        "application/x-bzip2",
        "application/x-xz",
        "application/zstd",
        "application/xml",
        "application/json",
        "application/pdf",
    }
)

TEXTUAL_MIME_PREFIXES = ("text/",)


def normalize_mime(value: str) -> str:
    """Lower-case a MIME name and drop parameters and whitespace."""
    if not value:
        return ""
    value = value.split(";", 1)[0].strip().lower()
    return value


def is_valid_mime(value: str) -> bool:
    return bool(MIME_PATTERN.match(normalize_mime(value)))


def humanize_mime(mime: str) -> str:
    """A readable fallback for a type the database does not describe."""
    mime = normalize_mime(mime)
    if not mime or "/" not in mime:
        return "unknown file type"
    top, subtype = mime.split("/", 1)
    subtype = subtype.replace("vnd.", "").replace("x-", "").replace("-", " ").replace(".", " ")
    subtype = subtype.replace("openxmlformats officedocument ", "")
    words = [word for word in subtype.split() if word]
    if not words:
        return top
    text_type = " ".join(words)
    if top == "text":
        return f"{text_type} text file"
    if top in {"image", "audio", "video", "font", "model"}:
        return f"{text_type} {top} file"
    return text_type


def _local_name(tag: str) -> str:
    """The local part of an ElementTree tag, with any XML namespace removed."""
    return tag.rsplit("}", 1)[-1]


@dataclass(frozen=True)
class GlobRule:
    pattern: str
    mime: str
    weight: int = 50
    case_sensitive: bool = False
    source: str = ""

    def matches(self, basename: str) -> bool:
        candidate = basename if self.case_sensitive else basename.lower()
        pattern = self.pattern if self.case_sensitive else self.pattern.lower()
        return fnmatch.fnmatchcase(candidate, pattern)

    @property
    def specificity(self) -> int:
        """How much of the name the pattern pins down.

        A literal suffix is more specific than a wildcard match, so
        ``*.tar.gz`` beats ``*.gz`` even when both carry weight 50.
        """
        without_wildcards = re.sub(r"[*?\[\]]", "", self.pattern)
        return len(without_wildcards)

    @property
    def extension(self) -> str:
        """The extension a simple ``*.ext`` glob describes, else empty."""
        if not self.pattern.startswith("*."):
            return ""
        extension = self.pattern[2:]
        if any(character in extension for character in "*?[]"):
            return ""
        return extension.lower()


@dataclass
class MimeTypeInfo:
    name: str
    description: str = ""
    globs: list[GlobRule] = field(default_factory=list)
    aliases: list[str] = field(default_factory=list)
    parents: list[str] = field(default_factory=list)
    icon: str = ""
    generic_icon: str = ""
    source: str = ""


@dataclass(frozen=True)
class GlobMatch:
    mime: str
    pattern: str
    weight: int
    specificity: int
    extension: str
    description: str

    @property
    def confidence(self) -> float:
        if not self.extension:
            return 0.55
        if len(self.extension) >= 4:
            return 0.9
        return 0.85


class TypeIndex:
    """The merged MIME database for one desktop."""

    def __init__(self) -> None:
        self.types: dict[str, MimeTypeInfo] = {}
        self.aliases: dict[str, str] = {}
        self.parents: dict[str, set[str]] = {}
        self.globs: list[GlobRule] = []
        self.extension_map: dict[str, list[str]] = {}
        self.source_files: list[Path] = []
        self._glob_cache: dict[str, list[GlobMatch]] = {}

    # -- construction ---------------------------------------------------

    @classmethod
    def load(cls, data_dirs: list[Path] | None = None,
             mime_types_files: list[Path] | None = None) -> "TypeIndex":
        index = cls()
        directories = data_dirs if data_dirs is not None else paths.mime_data_dirs()
        files = mime_types_files if mime_types_files is not None else paths.mime_types_files()
        index._load_globs(directories)
        index._load_aliases(directories)
        index._load_subclasses(directories)
        index._load_packages([directory / "packages" for directory in directories])
        index._load_mime_types(files)
        index._finalize()
        return index

    def _add_type(self, mime: str) -> MimeTypeInfo:
        info = self.types.get(mime)
        if info is None:
            info = MimeTypeInfo(name=mime)
            self.types[mime] = info
        return info

    def _record_source(self, path: Path) -> None:
        if path not in self.source_files:
            self.source_files.append(path)

    def _read_lines(self, path: Path):
        try:
            with path.open("r", encoding="utf-8", errors="replace") as handle:
                for line in handle:
                    line = line.strip()
                    if line and not line.startswith("#"):
                        yield line
        except OSError:
            return

    def _load_globs(self, directories: list[Path]) -> None:
        for directory in directories:
            for name in ("globs2", "globs"):
                path = directory / name
                if not path.is_file():
                    continue
                self._record_source(path)
                for line in self._read_lines(path):
                    rule = self._parse_glob_line(line, path)
                    if rule is not None:
                        self._add_glob(rule)
                break

    def _parse_glob_line(self, line: str, path: Path) -> GlobRule | None:
        if ":__NOGLOBS__" in line:
            return None
        parts = line.split(":", 2)
        if len(parts) != 3:
            return None
        weight_text, mime, remainder = parts
        try:
            weight = int(weight_text)
        except ValueError:
            return None
        mime = normalize_mime(mime)
        if not is_valid_mime(mime):
            return None
        case_sensitive = False
        pattern = remainder
        if remainder.endswith(":cs") or remainder.endswith(":ic"):
            pattern = remainder[:-3]
            case_sensitive = remainder.endswith(":cs")
        if not pattern:
            return None
        return GlobRule(pattern=pattern, mime=mime, weight=weight,
                        case_sensitive=case_sensitive, source=str(path))

    def _add_glob(self, rule: GlobRule) -> None:
        # A duplicated pattern from a higher-priority directory wins.
        for existing in self.globs:
            if existing.pattern == rule.pattern and existing.mime == rule.mime:
                return
        self.globs.append(rule)
        info = self._add_type(rule.mime)
        info.globs.append(rule)

    def _load_aliases(self, directories: list[Path]) -> None:
        for directory in directories:
            path = directory / "aliases"
            if not path.is_file():
                continue
            self._record_source(path)
            for line in self._read_lines(path):
                parts = line.split()
                if len(parts) != 2:
                    continue
                alias, mime = normalize_mime(parts[0]), normalize_mime(parts[1])
                if is_valid_mime(alias) and is_valid_mime(mime):
                    self.aliases.setdefault(alias, mime)

    def _load_subclasses(self, directories: list[Path]) -> None:
        for directory in directories:
            path = directory / "subclasses"
            if not path.is_file():
                continue
            self._record_source(path)
            for line in self._read_lines(path):
                parts = line.split()
                if len(parts) != 2:
                    continue
                child, parent = normalize_mime(parts[0]), normalize_mime(parts[1])
                if is_valid_mime(child) and is_valid_mime(parent):
                    self.parents.setdefault(child, set()).add(parent)
                    self._add_type(child).parents.append(parent)

    def _load_packages(self, directories: list[Path]) -> None:
        for directory in directories:
            if not directory.is_dir():
                continue
            for path in sorted(directory.glob("*.xml")):
                self._record_source(path)
                try:
                    tree = ElementTree.parse(path)
                except (ElementTree.ParseError, OSError):
                    continue
                for element in tree.getroot().iter():
                    if _local_name(element.tag) != "mime-type":
                        continue
                    mime = normalize_mime(element.get("type", ""))
                    if not is_valid_mime(mime):
                        continue
                    info = self._add_type(mime)
                    info.source = info.source or str(path)
                    self._read_package_type(element, info)

    @staticmethod
    def _read_package_type(element: ElementTree.Element, info: MimeTypeInfo) -> None:
        comments: dict[str, str] = {}
        for child in element:
            tag = _local_name(child.tag)
            if tag == "comment":
                language = child.get("{http://www.w3.org/XML/1998/namespace}lang", "")
                text = (child.text or "").strip()
                if text and language not in comments:
                    comments[language] = text
            elif tag == "glob":
                pattern = child.get("pattern", "")
                if not pattern:
                    continue
                try:
                    weight = int(child.get("weight", "50"))
                except ValueError:
                    weight = 50
                case_sensitive = child.get("case-sensitive", "false").lower() == "true"
                rule = GlobRule(pattern=pattern, mime=info.name, weight=weight,
                                case_sensitive=case_sensitive, source=info.source)
                if all(existing.pattern != pattern for existing in info.globs):
                    info.globs.append(rule)
            elif tag == "icon" and not info.icon:
                info.icon = child.get("name", "")
            elif tag == "generic-icon" and not info.generic_icon:
                info.generic_icon = child.get("name", "")
            elif tag == "alias":
                alias = normalize_mime(child.get("type", ""))
                if is_valid_mime(alias) and alias not in info.aliases:
                    info.aliases.append(alias)
            elif tag == "sub-class-of":
                parent = normalize_mime(child.get("type", ""))
                if is_valid_mime(parent) and parent not in info.parents:
                    info.parents.append(parent)
        if not info.description:
            info.description = comments.get("", "") or comments.get("en", "") or next(
                (value for value in comments.values() if value), ""
            )

    def _load_mime_types(self, files: list[Path]) -> None:
        for path in files:
            if not path.is_file():
                continue
            self._record_source(path)
            for line in self._read_lines(path):
                parts = line.split()
                if len(parts) < 2:
                    continue
                mime = normalize_mime(parts[0])
                if not is_valid_mime(mime):
                    continue
                self._add_type(mime)
                for extension in parts[1:]:
                    extension = extension.strip().lower()
                    if not extension or any(character in extension for character in "*?[]/"):
                        continue
                    rule = GlobRule(pattern=f"*.{extension}", mime=mime, weight=40,
                                    case_sensitive=False, source=str(path))
                    if not any(existing.pattern == rule.pattern for existing in self.globs):
                        self._add_glob(rule)

    def _finalize(self) -> None:
        # Package XML globs are added after globs2; merge them here so that
        # every glob participates in the same ranking, then sort.
        for info in self.types.values():
            for rule in info.globs:
                if not any(existing.pattern == rule.pattern and existing.mime == rule.mime
                           for existing in self.globs):
                    self.globs.append(rule)
        self.globs.sort(key=lambda rule: (-rule.weight, -rule.specificity, len(rule.pattern), rule.mime))

        for alias, target in BUILTIN_ALIASES.items():
            self.aliases.setdefault(alias, target)

        for info in self.types.values():
            if not info.description:
                info.description = humanize_mime(info.name)
            # An alias names a type; it does not need its own description.
            for alias in info.aliases:
                self.aliases.setdefault(alias, info.name)
                alias_info = self.types.get(alias)
                if alias_info is not None and not alias_info.description:
                    alias_info.description = info.description

        for rule in self.globs:
            extension = rule.extension
            if not extension:
                continue
            types = self.extension_map.setdefault(extension, [])
            if rule.mime not in types:
                types.append(rule.mime)

        for extension, types in self.extension_map.items():
            types.sort(key=lambda mime: (0 if mime not in GENERIC_MIME_TYPES else 1, mime))

    # -- queries --------------------------------------------------------

    def canonical(self, mime: str) -> str:
        mime = normalize_mime(mime)
        seen: set[str] = set()
        while mime in self.aliases and mime not in seen:
            seen.add(mime)
            mime = self.aliases[mime]
        return mime

    def aliases_for(self, mime: str) -> list[str]:
        mime = normalize_mime(mime)
        return sorted(alias for alias, target in self.aliases.items()
                      if target == mime or alias == mime)

    def ancestors(self, mime: str) -> list[str]:
        """Parents of a type, nearest first, excluding the type itself."""
        mime = self.canonical(mime)
        result: list[str] = []
        pending = list(self.parents.get(mime, ()))
        while pending:
            parent = pending.pop(0)
            if parent == mime or parent in result:
                continue
            result.append(parent)
            pending.extend(self.parents.get(parent, ()))
        return result

    def family(self, mime: str) -> list[str]:
        """The type, its aliases, and its ancestors, for matching a handler."""
        canonical = self.canonical(mime)
        result = [canonical]
        for alias in self.aliases_for(canonical):
            if alias not in result:
                result.append(alias)
        for parent in self.ancestors(canonical):
            if parent not in result:
                result.append(parent)
        return result

    def handler_family(self, mime: str) -> list[str]:
        """The types a handler may reasonably claim for this file.

        Shared-mime-info records odd ancestry: ``text/x-python`` is a
        subclass of ``application/x-executable``, so a debugger would appear
        as a Python handler.  Only the generic container and text parents
        are useful for widening a handler search.
        """
        canonical = self.canonical(mime)
        result = [canonical]
        for alias in self.aliases_for(canonical):
            if alias not in result:
                result.append(alias)
        for parent in self.ancestors(canonical):
            if parent in HANDLER_PARENTS and parent not in result:
                result.append(parent)
        return result

    def description(self, mime: str) -> str:
        canonical = self.canonical(mime)
        info = self.types.get(canonical)
        if info is not None and info.description:
            return info.description
        info = self.types.get(normalize_mime(mime))
        if info is not None and info.description:
            return info.description
        return humanize_mime(canonical)

    def icon(self, mime: str) -> str:
        canonical = self.canonical(mime)
        info = self.types.get(canonical)
        if info is not None and info.icon:
            return info.icon
        fallback = canonical.replace("/", "-")
        return fallback

    def generic_icon(self, mime: str) -> str:
        canonical = self.canonical(mime)
        info = self.types.get(canonical)
        if info is not None and info.generic_icon:
            return info.generic_icon
        return category_generic_icon(self.category(mime))

    def lookup_extension(self, filename: str) -> list[GlobMatch]:
        basename = os.path.basename(filename)
        if not basename:
            return []
        cached = self._glob_cache.get(basename)
        if cached is not None:
            return cached
        matches: list[GlobMatch] = []
        for rule in self.globs:
            if rule.matches(basename):
                matches.append(GlobMatch(
                    mime=rule.mime,
                    pattern=rule.pattern,
                    weight=rule.weight,
                    specificity=rule.specificity,
                    extension=rule.extension,
                    description=self.description(rule.mime),
                ))
        matches.sort(key=lambda match: (-match.weight, -match.specificity,
                                        -len(match.pattern), match.mime))
        # Collapse duplicate MIME types while preserving the best match.
        seen: set[str] = set()
        unique: list[GlobMatch] = []
        for match in matches:
            if match.mime in seen:
                continue
            seen.add(match.mime)
            unique.append(match)
        self._glob_cache[basename] = unique
        return unique

    def lookup_extension_name(self, extension: str) -> GlobMatch | None:
        extension = extension.strip().lower().lstrip(".")
        if not extension:
            return None
        matches = self.lookup_extension(f"name.{extension}")
        for match in matches:
            if match.extension == extension:
                return match
        return matches[0] if matches else None

    def extensions_for(self, mime: str) -> list[str]:
        canonical = self.canonical(mime)
        extensions = [extension for extension, types in self.extension_map.items()
                      if canonical in {self.canonical(item) for item in types}]
        return sorted(extensions, key=lambda item: (len(item), item))

    def category(self, mime: str) -> str:
        return category_of(self.canonical(mime))

    def type_count(self) -> int:
        return len(self.types)

    def extension_count(self) -> int:
        return len(self.extension_map)

    def stats(self) -> dict[str, object]:
        categories: dict[str, int] = {}
        for mime in self.types:
            category = self.category(mime)
            categories[category] = categories.get(category, 0) + 1
        return {
            "types": self.type_count(),
            "extensions": self.extension_count(),
            "globs": len(self.globs),
            "aliases": len(self.aliases),
            "subclasses": sum(len(parents) for parents in self.parents.values()),
            "categories": dict(sorted(categories.items())),
            "sources": [str(path) for path in self.source_files],
        }


CATEGORY_EXACT = {
    "inode/directory": "directory",
    "inode/symlink": "link",
    "inode/mount-point": "directory",
    "application/pdf": "document",
    "application/postscript": "document",
    "application/rtf": "document",
    "application/epub+zip": "ebook",
    "application/x-mobipocket-ebook": "ebook",
    "application/vnd.amazon.ebook": "ebook",
    "application/x-fictionbook+xml": "ebook",
    "application/x-msdownload": "executable",
    "application/x-executable": "executable",
    "application/x-sharedlib": "executable",
    "application/x-pie-executable": "executable",
    "application/x-shellscript": "code",
    "application/javascript": "code",
    "application/x-javascript": "code",
    "application/json": "data",
    "application/xml": "data",
    "application/yaml": "data",
    "application/toml": "data",
    "application/x-sqlite3": "database",
    "application/vnd.sqlite3": "database",
    "application/x-iso9660-image": "disk-image",
    "application/x-raw-disk-image": "disk-image",
    "application/x-apple-diskimage": "disk-image",
    "application/x-cd-image": "disk-image",
    "application/vnd.debian.binary-package": "package",
    "application/x-rpm": "package",
    "application/vnd.android.package-archive": "package",
    "application/x-flatpak": "package",
    "application/vnd.snap": "package",
    "application/zip": "archive",
    "application/gzip": "archive",
    "application/x-tar": "archive",
    "application/x-7z-compressed": "archive",
    "application/x-rar": "archive",
    "application/x-bzip2": "archive",
    "application/x-xz": "archive",
    "application/zstd": "archive",
    "application/x-lz4": "archive",
    "application/x-lzip": "archive",
    "application/vnd.rar": "archive",
    "message/rfc822": "email",
    "text/calendar": "calendar",
    "text/vcard": "contact",
    "text/x-vcard": "contact",
}

CATEGORY_PREFIX = {
    "image/": "image",
    "audio/": "audio",
    "video/": "video",
    "font/": "font",
    "model/": "model",
    "text/": "text",
}

CATEGORY_SUBTYPE = (
    ("wordprocessingml", "document"),
    ("spreadsheetml", "spreadsheet"),
    ("presentationml", "presentation"),
    ("opendocument.text", "document"),
    ("opendocument.spreadsheet", "spreadsheet"),
    ("opendocument.presentation", "presentation"),
    ("opendocument.graphics", "drawing"),
    ("ms-word", "document"),
    ("msword", "document"),
    ("ms-excel", "spreadsheet"),
    ("ms-powerpoint", "presentation"),
    ("x-compressed-tar", "archive"),
    ("compressed-tar", "archive"),
    ("x-tar", "archive"),
    ("x-7z", "archive"),
    ("x-rar", "archive"),
    ("vnd.rar", "archive"),
    ("x-bzip", "archive"),
    ("x-xz", "archive"),
    ("x-zstd", "archive"),
    ("x-lz4", "archive"),
    ("x-lzip", "archive"),
    ("x-cpio", "archive"),
    ("x-archive", "archive"),
    ("x-compressed", "archive"),
    ("java-archive", "package"),
    ("x-deb", "package"),
    ("x-appimage", "package"),
    ("x-msi", "package"),
    ("x-krita", "drawing"),
    ("photoshop", "drawing"),
    ("illustrator", "drawing"),
    ("corel-draw", "drawing"),
    ("x-blender", "model"),
    ("autocad", "cad"),
    ("dwg", "cad"),
    ("dxf", "cad"),
    ("stl", "model"),
    ("gcode", "model"),
    ("x-gcode", "model"),
    ("subtitle", "subtitle"),
    ("x-subrip", "subtitle"),
    ("ttml", "subtitle"),
    ("sql", "database"),
    ("x-sqlite", "database"),
    ("csv", "spreadsheet"),
    ("x-python", "code"),
    ("x-csrc", "code"),
    ("x-chdr", "code"),
    ("x-c++src", "code"),
    ("x-c++hdr", "code"),
    ("x-java", "code"),
    ("x-rust", "code"),
    ("x-go", "code"),
    ("x-php", "code"),
    ("x-ruby", "code"),
    ("x-perl", "code"),
    ("x-lua", "code"),
    ("x-shellscript", "code"),
    ("x-markdown", "text"),
    ("x-tex", "text"),
    ("x-latex", "text"),
    ("x-diff", "text"),
    ("x-patch", "text"),
    ("x-config", "text"),
    ("x-desktop", "text"),
    ("x-ini", "text"),
    ("x-log", "text"),
    ("x-nfo", "text"),
    ("x-readme", "text"),
    ("x-compress", "archive"),
    ("x-lz", "archive"),
)


def category_of(mime: str) -> str:
    mime = normalize_mime(mime)
    if mime in CATEGORY_EXACT:
        return CATEGORY_EXACT[mime]
    subtype = mime.split("/", 1)[-1]
    for marker, category in CATEGORY_SUBTYPE:
        if marker in subtype:
            return category
    for prefix, category in CATEGORY_PREFIX.items():
        if mime.startswith(prefix):
            return category
    return "data"


def category_generic_icon(category: str) -> str:
    return {
        "directory": "folder",
        "link": "emblem-symbolic-link",
        "text": "text-x-generic",
        "code": "text-x-script",
        "document": "x-office-document",
        "spreadsheet": "x-office-spreadsheet",
        "presentation": "x-office-presentation",
        "drawing": "image-x-generic",
        "image": "image-x-generic",
        "audio": "audio-x-generic",
        "video": "video-x-generic",
        "font": "font-x-generic",
        "archive": "package-x-generic",
        "package": "package-x-generic",
        "executable": "application-x-executable",
        "database": "x-office-spreadsheet",
        "data": "text-x-generic",
        "model": "image-x-generic",
        "cad": "image-x-generic",
        "disk-image": "media-optical",
        "ebook": "x-office-document",
        "email": "x-office-address-book",
        "calendar": "x-office-calendar",
        "contact": "x-office-address-book",
        "subtitle": "text-x-generic",
    }.get(category, "text-x-generic")


def category_label(category: str) -> str:
    return {
        "directory": "Folder",
        "link": "Link",
        "text": "Text",
        "code": "Source code",
        "document": "Document",
        "spreadsheet": "Spreadsheet",
        "presentation": "Presentation",
        "drawing": "Drawing",
        "image": "Image",
        "audio": "Audio",
        "video": "Video",
        "font": "Font",
        "archive": "Archive",
        "package": "Package",
        "executable": "Executable",
        "database": "Database",
        "data": "Data",
        "model": "3D model",
        "cad": "CAD drawing",
        "disk-image": "Disk image",
        "ebook": "Ebook",
        "email": "Email",
        "calendar": "Calendar",
        "contact": "Contact",
        "subtitle": "Subtitle",
    }.get(category, category.title())

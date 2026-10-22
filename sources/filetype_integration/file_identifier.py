"""Identify a file from its bytes and its name.

Two independent witnesses are used.  ``file`` reads the magic database and
describes the bytes; the shared-mime-info globs describe the name.  The
identifier prefers the more specific witness, keeps the other one visible, and
reports an explicit conflict when the two disagree instead of silently picking
a side.
"""

from __future__ import annotations

import os
import shutil
import subprocess
from dataclasses import dataclass, field
from pathlib import Path

from .mime_index import (GENERIC_MIME_TYPES, GlobMatch, TypeIndex, category_label,
                         humanize_mime, normalize_mime)


@dataclass
class MagicResult:
    mime: str = ""
    encoding: str = ""
    description: str = ""
    available: bool = True
    error: str = ""

    @property
    def known(self) -> bool:
        return bool(self.mime) and self.mime not in GENERIC_MIME_TYPES

    def to_dict(self) -> dict[str, object]:
        return {
            "mime": self.mime,
            "encoding": self.encoding,
            "description": self.description,
            "available": self.available,
            "error": self.error,
        }


@dataclass
class ExtensionHint:
    suffix: str = ""
    mime: str = ""
    description: str = ""
    matches: list[GlobMatch] = field(default_factory=list)

    @property
    def known(self) -> bool:
        return bool(self.mime)

    def to_dict(self) -> dict[str, object]:
        return {
            "suffix": self.suffix,
            "mime": self.mime,
            "description": self.description,
            "known": self.known,
            "alternatives": [
                {"mime": match.mime, "description": match.description,
                 "pattern": match.pattern}
                for match in self.matches[1:]
            ],
        }


@dataclass
class Identification:
    path: Path
    mime: str
    description: str
    category: str
    category_label: str
    source: str
    confidence: float
    magic: MagicResult
    extension: ExtensionHint
    conflict: dict[str, object] | None = None
    reasons: list[str] = field(default_factory=list)
    exists: bool = True
    is_directory: bool = False
    is_symlink: bool = False
    is_regular: bool = False
    size: int = 0
    generic_icon: str = ""

    @property
    def name(self) -> str:
        return self.path.name or str(self.path)

    @property
    def confidence_label(self) -> str:
        if 0.9 <= self.confidence:
            return "high"
        if 0.7 <= self.confidence:
            return "medium"
        return "low"

    def to_dict(self) -> dict[str, object]:
        return {
            "path": str(self.path),
            "name": self.name,
            "exists": self.exists,
            "is_directory": self.is_directory,
            "is_symlink": self.is_symlink,
            "is_regular": self.is_regular,
            "size": self.size,
            "mime": self.mime,
            "description": self.description,
            "category": self.category,
            "category_label": self.category_label,
            "generic_icon": self.generic_icon,
            "source": self.source,
            "confidence": round(self.confidence, 2),
            "confidence_label": self.confidence_label,
            "magic": self.magic.to_dict(),
            "extension": self.extension.to_dict(),
            "conflict": self.conflict,
            "reasons": list(self.reasons),
        }


def format_size(size: int) -> str:
    if 0 <= size < 1024:
        return f"{size} B"
    units = ("KiB", "MiB", "GiB", "TiB", "PiB")
    value = float(size)
    for unit in units:
        value /= 1024.0
        if value < 1024.0:
            return f"{value:.1f} {unit}"
    return f"{value:.1f} EiB"


def _run_file(arguments: list[str], timeout: float = 10.0) -> tuple[str, str]:
    executable = shutil.which("file")
    if executable is None:
        return "", "the file utility is not installed"
    environment = dict(os.environ)
    environment["LC_ALL"] = "C"
    try:
        result = subprocess.run(
            [executable, *arguments],
            capture_output=True,
            text=True,
            timeout=timeout,
            env=environment,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        return "", str(error)
    if result.returncode != 0:
        message = (result.stderr or result.stdout).strip()
        return "", message or f"file exited {result.returncode}"
    return result.stdout.strip(), ""


def magic_probe(path: Path, want_description: bool = True) -> MagicResult:
    """Ask libmagic what the bytes are."""
    if not path.exists():
        return MagicResult(available=shutil.which("file") is not None,
                           error="path does not exist")
    output, error = _run_file(["--brief", "--mime-type", "--mime-encoding", "--", str(path)])
    if error:
        return MagicResult(error=error)
    mime = ""
    encoding = ""
    for part in output.split(";"):
        part = part.strip()
        if part.startswith("charset="):
            encoding = part.split("=", 1)[1].strip()
        elif part and not mime:
            mime = normalize_mime(part)
    description = ""
    if want_description:
        description, description_error = _run_file(["--brief", "--", str(path)])
        if description_error:
            description = ""
    return MagicResult(mime=mime, encoding=encoding, description=description)


def extension_hint(path: Path, index: TypeIndex) -> ExtensionHint:
    basename = path.name
    if not basename:
        return ExtensionHint()
    matches = index.lookup_extension(basename)
    if matches:
        best = matches[0]
        return ExtensionHint(suffix=best.extension, mime=best.mime,
                             description=best.description, matches=matches)
    # An unknown suffix is still worth naming in the report.  A hidden file
    # such as .bashrc has no suffix; its whole name is the glob, so do not
    # call it an extension.
    suffix = Path(basename).suffix.lower()
    if basename.startswith(".") and basename.count(".") == 1:
        suffix = ""
    if suffix.startswith("."):
        suffix = suffix[1:]
    return ExtensionHint(suffix=suffix)


def _compatible(magic_mime: str, extension_mime: str, index: TypeIndex) -> bool:
    magic_canonical = index.canonical(magic_mime)
    extension_canonical = index.canonical(extension_mime)
    if magic_canonical == extension_canonical:
        return True
    if magic_canonical in index.family(extension_canonical):
        return True
    if extension_canonical in index.family(magic_canonical):
        return True
    return False


def identify(path: str | os.PathLike[str], index: TypeIndex | None = None) -> Identification:
    """Identify one path.  Never throws for a missing file; reports it."""
    index = index or TypeIndex.load()
    target = Path(path).expanduser()
    try:
        stat_result = target.lstat()
        exists = True
    except OSError:
        exists = False
        stat_result = None

    is_symlink = bool(stat_result and os.path.islink(target))
    is_directory = False
    is_regular = False
    size = 0
    if stat_result is not None:
        try:
            followed = target.stat()
        except OSError:
            followed = stat_result
        is_directory = followed.st_mode and os.path.isdir(target)
        is_regular = followed.st_mode and os.path.isfile(target)
        size = followed.st_size

    if not exists:
        return Identification(
            path=target,
            mime="application/x-missing-file",
            description="Missing file",
            category="unknown",
            category_label=category_label("unknown"),
            source="filesystem",
            confidence=1.0,
            magic=MagicResult(error="path does not exist"),
            extension=ExtensionHint(),
            exists=False,
            generic_icon="text-x-generic",
            reasons=["The path does not exist on this machine."],
        )

    if is_directory:
        return Identification(
            path=target,
            mime="inode/directory",
            description=index.description("inode/directory"),
            category="directory",
            category_label=category_label("directory"),
            source="filesystem",
            confidence=1.0,
            magic=MagicResult(mime="inode/directory", description="directory"),
            extension=ExtensionHint(),
            exists=True,
            is_directory=True,
            is_symlink=is_symlink,
            is_regular=False,
            size=size,
            generic_icon="folder",
            reasons=["The path is a directory, not a file."],
        )

    hint = extension_hint(target, index)
    magic = magic_probe(target)
    reasons: list[str] = []

    if magic.mime:
        reasons.append(f"libmagic reports {magic.mime}" +
                       (f" ({magic.encoding})" if magic.encoding else "") + ".")
    elif magic.error:
        reasons.append(f"libmagic could not answer: {magic.error}.")
    if hint.mime:
        reasons.append(f"The name ends in .{hint.suffix}, which means {hint.mime}.")

    chosen = ""
    source = "fallback"
    confidence = 0.3
    conflict: dict[str, object] | None = None

    magic_specific = bool(magic.mime) and magic.mime not in GENERIC_MIME_TYPES
    if magic_specific and hint.mime:
        if _compatible(magic.mime, hint.mime, index):
            chosen = hint.mime
            source = "agreement"
            confidence = 0.97
            reasons.append("The bytes and the name agree; the name is the more specific type.")
        else:
            chosen = magic.mime
            source = "content"
            confidence = 0.82
            conflict = {
                "content_mime": magic.mime,
                "name_mime": hint.mime,
                "resolution": "content",
                "explanation": (
                    f"The bytes look like {index.description(magic.mime)} but the name "
                    f"suggests {index.description(hint.mime)}. The bytes win; the file "
                    "may have been renamed."
                ),
            }
            reasons.append(conflict["explanation"])
    elif magic_specific:
        chosen = magic.mime
        source = "content"
        confidence = 0.95
        reasons.append("No known extension; the content identifies the type.")
    elif hint.mime:
        chosen = hint.mime
        source = "name"
        confidence = 0.8 if magic.mime else 0.68
        if magic.mime in GENERIC_MIME_TYPES:
            reasons.append(
                f"The bytes are only {magic.mime}, so the extension supplies the type."
            )
        else:
            reasons.append("The extension supplies the type because libmagic was unavailable.")
    elif magic.mime:
        chosen = magic.mime
        source = "content"
        confidence = 0.35
        reasons.append("Only a generic content type was found and the name is not known.")
    else:
        chosen = "application/octet-stream"
        source = "fallback"
        confidence = 0.2
        reasons.append("Neither the bytes nor the name identify this file.")

    chosen = index.canonical(chosen)
    description = index.description(chosen)
    category = index.category(chosen)
    if not description or description == humanize_mime(chosen):
        description = magic.description or description

    return Identification(
        path=target,
        mime=chosen,
        description=description,
        category=category,
        category_label=category_label(category),
        source=source,
        confidence=confidence,
        magic=magic,
        extension=hint,
        conflict=conflict,
        reasons=reasons,
        exists=True,
        is_directory=False,
        is_symlink=is_symlink,
        is_regular=is_regular,
        size=size,
        generic_icon=index.generic_icon(chosen),
    )


def identify_many(paths: list[str], index: TypeIndex | None = None) -> list[Identification]:
    index = index or TypeIndex.load()
    return [identify(path, index) for path in paths]

"""XDG paths used by the tool.

Every path is resolved from the environment at call time, never at import
time, so a test can sandbox a whole desktop by setting ``HOME``,
``XDG_DATA_HOME``, ``XDG_CONFIG_HOME``, and ``XDG_DATA_DIRS`` before it calls
into the package.
"""

from __future__ import annotations

import os
from pathlib import Path

PROGRAM_NAME = "gnome-filetype-integration"
HANDLER_DESKTOP_ID = "filetype-handler.desktop"
HANDLER_NAME = "filetype-handler"
HANDLER_ICON_NAME = "filetype-chooser"
MANIFEST_NAME = "handler-manifest.json"
NAUTILUS_EXTENSION_NAME = "filetype_nautilus.py"


def _home() -> Path:
    return Path(os.environ.get("HOME", str(Path.home()))).expanduser()


def _absolute_environment_path(name: str, default: str) -> list[Path]:
    value = os.environ.get(name)
    if not value:
        value = default
    paths: list[Path] = []
    for item in value.split(os.pathsep):
        item = item.strip()
        if not item:
            continue
        path = Path(item).expanduser()
        if not path.is_absolute():
            continue
        if path not in paths:
            paths.append(path)
    return paths


def data_home() -> Path:
    value = os.environ.get("XDG_DATA_HOME")
    if value:
        path = Path(value).expanduser()
        if path.is_absolute():
            return path
    return _home() / ".local" / "share"


def data_dirs() -> list[Path]:
    return _absolute_environment_path("XDG_DATA_DIRS", "/usr/local/share:/usr/share")


def config_home() -> Path:
    value = os.environ.get("XDG_CONFIG_HOME")
    if value:
        path = Path(value).expanduser()
        if path.is_absolute():
            return path
    return _home() / ".config"


def config_dirs() -> list[Path]:
    return _absolute_environment_path("XDG_CONFIG_DIRS", "/etc/xdg")


def cache_home() -> Path:
    value = os.environ.get("XDG_CACHE_HOME")
    if value:
        path = Path(value).expanduser()
        if path.is_absolute():
            return path
    return _home() / ".cache"


def applications_dirs() -> list[Path]:
    """Directories searched for desktop entries, highest priority first."""
    directories: list[Path] = [data_home() / "applications"]
    for directory in data_dirs():
        candidate = directory / "applications"
        if candidate not in directories:
            directories.append(candidate)
    return directories


def mime_data_dirs() -> list[Path]:
    directories: list[Path] = []
    for directory in [data_home(), *data_dirs()]:
        candidate = directory / "mime"
        if candidate not in directories:
            directories.append(candidate)
    return directories


def mime_packages_dirs() -> list[Path]:
    return [directory / "packages" for directory in mime_data_dirs()]


def mime_types_files() -> list[Path]:
    """Files in the ``mime.types`` format, lowest priority last."""
    files: list[Path] = []
    override = os.environ.get("FILETYPE_MIME_TYPES_FILE")
    if override:
        candidate = Path(override).expanduser()
        if candidate.is_absolute():
            files.append(candidate)
        return files
    for candidate in (Path("/etc/mime.types"), Path("/etc/httpd/mime.types")):
        if candidate not in files:
            files.append(candidate)
    return files


def handler_manifest_path() -> Path:
    return data_home() / PROGRAM_NAME / MANIFEST_NAME


def handler_desktop_path() -> Path:
    return data_home() / "applications" / HANDLER_DESKTOP_ID


def handler_icon_path() -> Path:
    return data_home() / "icons" / "hicolor" / "scalable" / "apps" / f"{HANDLER_ICON_NAME}.svg"


def nautilus_extension_dir() -> Path:
    return data_home() / "nautilus-python" / "extensions"


def nautilus_extension_path() -> Path:
    return nautilus_extension_dir() / NAUTILUS_EXTENSION_NAME


def cache_dir() -> Path:
    return cache_home() / PROGRAM_NAME


def mimeapps_files() -> list[Path]:
    """mimeapps files in the search order the desktop specification uses.

    The desktop-specific file wins over the generic one in the same
    directory.  The user configuration directory wins over the user data
    directory, which wins over the system directories.
    """
    desktop = os.environ.get("XDG_CURRENT_DESKTOP", "").split(":")[0].strip()
    files: list[Path] = []
    for base in [config_home(), data_home(), *config_dirs()]:
        if desktop:
            candidate = base / f"{desktop.lower()}-mimeapps.list"
            if candidate not in files:
                files.append(candidate)
        candidate = base / "mimeapps.list"
        if candidate not in files:
            files.append(candidate)
    return files


def writable_mimeapps_path() -> Path:
    """The file this tool writes when it changes a default association.

    A desktop-specific file already on disk takes precedence over the generic
    one, so that is the file to edit; otherwise the generic user file is used.
    The generic file stays the readable, portable default.
    """
    desktop = os.environ.get("XDG_CURRENT_DESKTOP", "").split(":")[0].strip()
    if desktop:
        candidate = config_home() / f"{desktop.lower()}-mimeapps.list"
        if candidate.is_file():
            return candidate
    return config_home() / "mimeapps.list"

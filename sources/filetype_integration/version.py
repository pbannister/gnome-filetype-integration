"""Build-time version information.

``version_info.py`` is generated from git state by
``scripts/version-generate.sh`` and staged by ``scripts/program-build.sh``.
The source checkout has no version of its own; a checkout that has not been
built reports ``development`` rather than inventing a release number.
"""

from __future__ import annotations

try:
    from .version_info import BUILD_COUNTER as _BUILD_COUNTER  # type: ignore
    from .version_info import VERSION_STRING as _VERSION_STRING  # type: ignore
except ImportError:  # pragma: no cover - exercised by an unbuilt checkout
    _VERSION_STRING = "development"
    _BUILD_COUNTER = 0


def version_string() -> str:
    return _VERSION_STRING


def version_build_counter() -> int:
    return int(_BUILD_COUNTER)


def version_line(program: str = "filetype") -> str:
    return f"{program} {version_string()} (build {version_build_counter()})"

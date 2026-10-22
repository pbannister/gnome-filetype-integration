"""Nautilus right-click integration for the file type chooser.

This file is copied into ``$XDG_DATA_HOME/nautilus-python/extensions/`` by
``filetype handler install`` when the Nautilus Python bindings are present.
It is never imported by the command-line tool.
"""

from __future__ import annotations

import os
import shutil
import subprocess

from gi.repository import GObject, Nautilus


def _filetype_command() -> str:
    found = shutil.which("filetype")
    if found:
        return found
    for candidate in (
        os.path.expanduser("~/.local/bin/filetype"),
        os.path.expanduser("~/bin/filetype"),
        "/usr/local/bin/filetype",
        "/usr/bin/filetype",
    ):
        if os.path.isfile(candidate) and os.access(candidate, os.X_OK):
            return candidate
    return "filetype"


def _path_for(file_info) -> str:
    try:
        location = file_info.get_location()
        path = location.get_path()
        if path:
            return path
    except Exception:
        pass
    try:
        return file_info.get_uri()
    except Exception:
        return ""


def _launch(arguments: list[str]) -> None:
    try:
        subprocess.Popen(
            arguments,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
            close_fds=True,
        )
    except OSError:
        pass


class FiletypeExtension(GObject.GObject, Nautilus.MenuProvider):
    """Adds the chooser and the inspector to the Nautilus context menu."""

    def _items(self, files):
        if not files:
            return []
        paths = [path for path in (_path_for(file_info) for file_info in files) if path]
        if not paths:
            return []
        executable = _filetype_command()
        items = []
        choose = Nautilus.MenuItem(
            name="FiletypeExtension::choose",
            label="Choose Application…",
            tip="Inspect this file and pick the application that opens it",
        )
        choose.connect("activate", lambda _item: _launch([executable, "choose", paths[0]]))
        items.append(choose)
        for path in paths[:1]:
            inspect = Nautilus.MenuItem(
                name="FiletypeExtension::inspect",
                label="Inspect File Type",
                tip="Show the detected type, the evidence, and every application that can open it",
            )
            inspect.connect("activate", lambda _item, target=path: _launch(
                [executable, "identify", "--apps", target]))
            items.append(inspect)
        return items

    def get_file_items(self, *args):
        files = args[-1] if args else []
        try:
            return self._items(files)
        except Exception:
            return []

    def get_background_items(self, *args):
        return []

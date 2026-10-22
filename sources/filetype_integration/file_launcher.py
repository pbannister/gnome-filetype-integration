"""Launch a file in the chosen application, and the fallback actions.

Nothing here goes through a shell: an Exec line is split into an argument
vector, the file is substituted as one argument, and the process is spawned
directly.  A desktop application that needs a terminal gets one.
"""

from __future__ import annotations

import os
import shlex
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

from .desktop_application import InstalledApplication, executable_from_command
from .paths import data_home

TERMINALS = (
    ("x-terminal-emulator", ("-e",)),
    ("kgx", ("--",)),
    ("gnome-terminal", ("--",)),
    ("konsole", ("-e",)),
    ("xfce4-terminal", ("-x",)),
    ("alacritty", ("-e",)),
    ("kitty", ()),
    ("xterm", ("-e",)),
)


@dataclass
class LaunchResult:
    ok: bool
    command: list[str]
    message: str = ""
    method: str = ""

    def to_dict(self) -> dict[str, object]:
        return {
            "ok": self.ok,
            "command": list(self.command),
            "message": self.message,
            "method": self.method,
        }


def find_terminal() -> tuple[str, tuple[str, ...]] | None:
    for name, arguments in TERMINALS:
        path = shutil.which(name)
        if path:
            return path, arguments
    return None


def _spawn(arguments: list[str], detached: bool = True) -> LaunchResult:
    if not arguments:
        return LaunchResult(False, [], "No command was produced for this application.")
    try:
        process = subprocess.Popen(
            arguments,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=detached,
            close_fds=True,
        )
    except OSError as error:
        return LaunchResult(False, arguments, f"Could not start the application: {error}")
    return LaunchResult(True, arguments,
                        f"Started {os.path.basename(arguments[0])} (pid {process.pid}).",
                        method="spawn")


def app_command(application: InstalledApplication, path: str) -> list[str]:
    argv = application.command_for(path)
    if not argv:
        return []
    # An Exec line without a field code did not say how to pass the file.
    # Appending the path is the convention for such entries.
    if "%" not in application.exec_line and "{file}" not in application.exec_line:
        if all(str(path) != argument for argument in argv):
            argv.append(str(path))
    return argv


def launch_application(application: InstalledApplication, path: str,
                       dry_run: bool = False,
                       prefer_terminal: bool = False) -> LaunchResult:
    argv = app_command(application, path)
    if not argv:
        return LaunchResult(False, [], f"{application.name} has no executable command.")
    if not application.executable_available:
        return LaunchResult(
            False, argv,
            f"{application.name} is registered, but its program "
            f"({application.executable or 'unknown'}) was not found.",
            method="missing",
        )
    needs_terminal = prefer_terminal or application.terminal or application.executable.endswith(
        ("/vim", "/nvim", "/emacs", "/hx", "/vim.basic"))
    if needs_terminal:
        terminal = find_terminal()
        if terminal is None:
            return LaunchResult(False, argv,
                                f"{application.name} runs in a terminal, and no terminal emulator was found.",
                                method="terminal")
        terminal_path, terminal_arguments = terminal
        argv = [terminal_path, *terminal_arguments, *argv]
    if dry_run:
        return LaunchResult(True, argv, "Dry run: the application was not started.", method="dry-run")
    return _spawn(argv)


def launch_path(path: str, application: InstalledApplication | None = None,
                dry_run: bool = False) -> LaunchResult:
    if application is not None:
        return launch_application(application, path, dry_run=dry_run)
    return open_default(path, dry_run=dry_run)


def open_default(path: str, dry_run: bool = False) -> LaunchResult:
    if os.environ.get("FILETYPE_INTEGRATION_NO_GIO") != "1":
        try:
            from gi.repository import Gio  # type: ignore
        except (ImportError, ValueError):
            Gio = None  # type: ignore
        if Gio is not None:
            try:
                file = Gio.File.new_for_path(str(path))
                Gio.AppInfo.launch_default_for_uri(file.get_uri(), None)
                return LaunchResult(True, [f"gio open {path}"], "Opened with the default application.",
                                    method="gio")
            except Exception:
                pass
    command = shutil.which("xdg-open")
    if command is None:
        return LaunchResult(False, [], "No default-opening mechanism is available.")
    if dry_run:
        return LaunchResult(True, [command, str(path)],
                            "Dry run: the default application was not started.", method="dry-run")
    return _spawn([command, str(path)])


def reveal_in_file_manager(path: str, dry_run: bool = False) -> LaunchResult:
    target = os.path.abspath(path)
    directory = target if os.path.isdir(target) else os.path.dirname(target)
    nautilus = shutil.which("nautilus")
    if nautilus:
        command = [nautilus, "--select", target] if not os.path.isdir(target) else [nautilus, target]
        if dry_run:
            return LaunchResult(True, command, "Dry run: the file manager was not started.", method="dry-run")
        return _spawn(command)
    xdg = shutil.which("xdg-open")
    if xdg:
        if dry_run:
            return LaunchResult(True, [xdg, directory], "Dry run: the file manager was not started.",
                                method="dry-run")
        return _spawn([xdg, directory])
    return LaunchResult(False, [], "No file manager launcher was found.")


def open_as_text(path: str, installed_index=None, dry_run: bool = False) -> LaunchResult:
    """Open a file as plain text, even when its type is unknown."""
    if installed_index is not None:
        for application in installed_index.for_mime("text/plain"):
            if application.executable_available:
                return launch_application(application, path, dry_run=dry_run)
    for name in ("gnome-text-editor", "gedit", "kate", "mousepad", "xed", "vim", "nano"):
        path_executable = shutil.which(name)
        if path_executable:
            if name in {"vim", "nano"}:
                terminal = find_terminal()
                if terminal is None:
                    continue
                terminal_path, terminal_arguments = terminal
                command = [terminal_path, *terminal_arguments, path_executable, str(path)]
            else:
                command = [path_executable, str(path)]
            if dry_run:
                return LaunchResult(True, command, "Dry run: the editor was not started.",
                                    method="dry-run")
            return _spawn(command)
    return LaunchResult(False, [], "No text editor was found.")


def command_text(arguments: list[str]) -> str:
    return " ".join(shlex.quote(argument) for argument in arguments)


def handler_exec_path() -> str:
    """The command a desktop entry should use to run this tool."""
    override = os.environ.get("FILETYPE_EXECUTABLE")
    if override and os.path.isabs(override):
        return override
    executable = shutil.which("filetype")
    if executable:
        return executable
    # A wrapper invoked by an absolute path knows where it lives even when its
    # directory is not on PATH.
    if sys.argv and Path(sys.argv[0]).name == "filetype":
        candidate = Path(sys.argv[0]).resolve()
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return str(candidate)
    candidate = data_home() / "bin" / "filetype"
    if candidate.is_file():
        return str(candidate)
    return "filetype"


def split_command(command: str) -> list[str]:
    try:
        return shlex.split(command)
    except ValueError:
        return command.split()

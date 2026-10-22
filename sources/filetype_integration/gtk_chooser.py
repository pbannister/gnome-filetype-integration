"""The GTK4 window that shows a file and asks what should open it.

The window is deliberately informational: it says what the file is, how that
was decided, which installed applications can open it, and which applications
would be worth installing.  Every action it offers has a printed command-line
equivalent, and the window shows that command.
"""

from __future__ import annotations

import os
import subprocess
import sys
import threading
from pathlib import Path

from .about_links import (AboutLink, category_for_url, check_about_urls,
                          group_links, link_label, open_uri)
from .application_catalog import (RankedApplication, Recommendation, install_argv,
                                  install_commands, recommend)
from .desktop_application import ApplicationIndex
from .file_identifier import Identification, format_size, identify
from .file_launcher import command_text, launch_application, open_as_text, open_default, reveal_in_file_manager
from .mime_index import TypeIndex


def _gtk():
    import gi
    gi.require_version("Gtk", "4.0")
    gi.require_version("Gdk", "4.0")
    from gi.repository import Gdk, Gtk
    return Gdk, Gtk


def _adw():
    try:
        import gi
        gi.require_version("Adw", "1")
        from gi.repository import Adw
        return Adw
    except (ImportError, ValueError):
        return None


def _escape(text: str) -> str:
    return (text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"))


def _icon_name(identification: Identification) -> str:
    return identification.mime.replace("/", "-")


def _resolve_icon(display, name: str, fallback: str = "application-x-executable") -> str:
    if not name:
        return fallback
    try:
        theme = _gtk()[1].IconTheme.get_for_display(display)
        if theme is not None and theme.has_icon(name):
            return name
    except Exception:
        pass
    try:
        theme = _gtk()[1].IconTheme.get_for_display(display)
        if theme is not None and theme.has_icon(fallback):
            return fallback
    except Exception:
        pass
    return fallback


def _css() -> str:
    return """
    .filetype-card { padding: 16px; border-radius: 14px; background: alpha(currentColor, 0.06); }
    .filetype-dim { opacity: 0.72; }
    .filetype-badge { padding: 2px 8px; border-radius: 999px; background: alpha(currentColor, 0.10); font-size: 0.85em; }
    .filetype-warning { padding: 12px; border-radius: 10px; background: alpha(#e5a50a, 0.18); }
    .filetype-danger { padding: 12px; border-radius: 10px; background: alpha(#e01b24, 0.15); }
    .filetype-mono { font-family: monospace; font-size: 0.9em; }
    .filetype-about { font-size: 0.9em; }
    .filetype-title { font-size: 1.35em; font-weight: bold; }
    .filetype-section { font-weight: bold; margin-top: 6px; }
    """


def load(path: str, index: TypeIndex | None = None) -> tuple[Identification, Recommendation, ApplicationIndex]:
    index = index or TypeIndex.load()
    identification = identify(path, index)
    installed = ApplicationIndex(index=index)
    recommendation = recommend(identification, installed, index=index)
    return identification, recommendation, installed


def _copy(display, text: str) -> None:
    try:
        display.get_clipboard().set(text)
    except Exception:
        pass


def _message(parent, heading: str, body: str) -> None:
    _gdk, Gtk = _gtk()
    window = Gtk.Window(transient_for=parent, modal=True, title=heading)
    window.set_default_size(560, 220)
    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
    box.set_margin_top(18)
    box.set_margin_bottom(18)
    box.set_margin_start(18)
    box.set_margin_end(18)
    title = Gtk.Label(label=heading)
    title.add_css_class("filetype-title")
    title.set_wrap(True)
    title.set_xalign(0)
    box.append(title)
    detail = Gtk.Label(label=body)
    detail.set_wrap(True)
    detail.set_xalign(0)
    detail.set_selectable(True)
    box.append(detail)
    close = Gtk.Button(label="Close")
    close.set_halign(Gtk.Align.END)
    close.connect("clicked", lambda _button: window.close())
    box.append(close)
    window.set_child(box)
    window.present()


def _append_output(buffer, text: str) -> None:
    if not text:
        return
    buffer.insert(buffer.get_end_iter(), text)


def _run_install(parent, window, argv: list[str], buffer, status, buttons: list) -> None:
    """Run one install command in the background and stream its output."""
    _gdk, Gtk = _gtk()
    from gi.repository import GLib

    runnable = [button for button in buttons if button.get_sensitive()]
    for button in buttons:
        button.set_sensitive(False)
    buffer.set_text("")
    _append_output(buffer, f"$ {' '.join(argv)}\n\n")
    status.set_text("Running…")

    def append(text):
        _append_output(buffer, text)
        return False

    def finished(code, error=""):
        for button in runnable:
            button.set_sensitive(True)
        if error:
            status.set_text(f"Could not start the installer: {error}")
            _append_output(buffer, f"\n{error}\n")
        else:
            status.set_text(
                f"Finished with exit code {code}. Reopen the chooser to see the "
                "new handler; install output is above."
            )
        return False

    def worker():
        try:
            process = subprocess.Popen(
                argv,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
                start_new_session=True,
            )
        except OSError as error:
            GLib.idle_add(finished, -1, str(error))
            return
        if process.stdout is not None:
            for line in process.stdout:
                GLib.idle_add(append, line)
        code = process.wait()
        GLib.idle_add(finished, code)

    threading.Thread(target=worker, daemon=True).start()


def _install_dialog(parent, application: RankedApplication) -> None:
    _gdk, Gtk = _gtk()
    window = Gtk.Window(transient_for=parent, modal=True,
                        title=f"Install {application.name}")
    window.set_default_size(720, 540)
    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
    for side in ("top", "bottom", "start", "end"):
        getattr(box, f"set_margin_{side}")(18)
    heading = Gtk.Label(label=f"Install {application.name}")
    heading.add_css_class("filetype-title")
    heading.set_xalign(0)
    box.append(heading)
    purpose = Gtk.Label(label=application.purpose)
    purpose.set_wrap(True)
    purpose.set_xalign(0)
    purpose.add_css_class("filetype-dim")
    box.append(purpose)

    commands = install_commands(application.catalog) if application.catalog else []
    if not commands:
        box.append(Gtk.Label(label="No install command is recorded for this application."))

    output = Gtk.TextView()
    output.set_editable(False)
    output.set_cursor_visible(False)
    output.set_monospace(True)
    output.set_wrap_mode(Gtk.WrapMode.WORD_CHAR)
    output.add_css_class("filetype-mono")
    buffer = output.get_buffer()
    buffer.set_text("Install output will appear here.\n")
    output_scroll = Gtk.ScrolledWindow()
    output_scroll.set_child(output)
    output_scroll.set_min_content_height(180)
    output_scroll.set_vexpand(True)
    box.append(output_scroll)

    status = Gtk.Label(label="")
    status.set_xalign(0)
    status.set_wrap(True)
    status.add_css_class("filetype-dim")
    box.append(status)

    run_buttons: list = []
    for entry in commands:
        argv = install_argv(entry)
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        label = Gtk.Label(label=entry["command"])
        label.add_css_class("filetype-mono")
        label.set_selectable(True)
        label.set_xalign(0)
        label.set_hexpand(True)
        row.append(label)
        copy = Gtk.Button(label="Copy")
        copy.connect("clicked", lambda _button, text=entry["command"]:
                     _copy(parent.get_display(), text))
        row.append(copy)
        run_label = "Open Page" if entry.get("method") == "download" else "Run"
        run = Gtk.Button(label=run_label)
        run.add_css_class("suggested-action")
        if argv:
            run.connect("clicked", lambda _button, command=argv:
                        _run_install(parent, window, command, buffer, status, run_buttons))
        else:
            run.set_sensitive(False)
            run.set_tooltip_text("No supported installer is available on this machine.")
        run_buttons.append(run)
        row.append(run)
        box.append(row)

    if application.installed:
        note = Gtk.Label(label="This program is already installed; the command is shown for reference.")
        note.set_wrap(True)
        note.set_xalign(0)
        box.append(note)
    close = Gtk.Button(label="Close")
    close.set_halign(Gtk.Align.END)
    close.connect("clicked", lambda _button: window.close())
    box.append(close)
    window.set_child(box)
    window.present()
    return window


def _badge(text: str):
    _gdk, Gtk = _gtk()
    label = Gtk.Label(label=text)
    label.add_css_class("filetype-badge")
    return label


def _about_dialog(parent, application: RankedApplication):
    """Show the About candidates grouped by kind, probing them concurrently."""
    _gdk, Gtk = _gtk()
    window = Gtk.Window(transient_for=parent, modal=True,
                        title=f"About {application.name}")
    window.set_default_size(760, 620)
    try:
        window.set_destroy_with_parent(True)
    except Exception:
        pass

    outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
    for side in ("top", "bottom", "start", "end"):
        getattr(outer, f"set_margin_{side}")(18)
    heading = Gtk.Label(label=f"About {application.name}")
    heading.add_css_class("filetype-title")
    heading.set_xalign(0)
    outer.append(heading)
    purpose = Gtk.Label(label=application.purpose)
    purpose.set_wrap(True)
    purpose.set_xalign(0)
    purpose.add_css_class("filetype-dim")
    outer.append(purpose)

    links = application.about_links
    if not links:
        outer.append(Gtk.Label(label="No candidate pages are recorded for this application."))
    else:
        scroller = Gtk.ScrolledWindow()
        scroller.set_vexpand(True)
        content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        rows: dict[str, tuple[object, object]] = {}
        for category, grouped in group_links(links):
            category_label = Gtk.Label(label=category)
            category_label.set_xalign(0)
            category_label.add_css_class("filetype-section")
            content.append(category_label)
            for link in grouped:
                row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
                link_button = Gtk.LinkButton.new_with_label(link.url, link.label or link_label(link.url))
                link_button.set_halign(Gtk.Align.START)
                link_button.set_hexpand(True)
                link_button.set_sensitive(False)
                link_button.set_tooltip_text(link.url)
                status = Gtk.Label(label="Checking…")
                status.set_xalign(1)
                status.add_css_class("filetype-dim")
                status.set_size_request(130, -1)
                row.append(link_button)
                row.append(status)
                content.append(row)
                rows[link.url] = (link_button, status)
        scroller.set_child(content)
        outer.append(scroller)

        def update(result) -> bool:
            row = rows.get(result.url)
            if row is None:
                return False
            link_button, status = row
            link_button.set_sensitive(bool(result.ok))
            if result.ok:
                status.set_text("Available (checked today)" if result.from_cache else "Available")
            else:
                status.set_text("No response (checked today)" if result.from_cache else "No response")
            return False

        def worker() -> None:
            from gi.repository import GLib
            try:
                check_about_urls(
                    [link.url for link in links],
                    on_result=lambda result: GLib.idle_add(update, result),
                )
            except Exception as error:
                print(f"filetype: About check failed: {error}", file=sys.stderr)

        threading.Thread(target=worker, daemon=True).start()

    close = Gtk.Button(label="Close")
    close.set_halign(Gtk.Align.END)
    close.connect("clicked", lambda _button: window.close())
    outer.append(close)
    window.set_child(outer)
    window.present()
    return window


def _about_clicked(parent, application: RankedApplication, link) -> bool:
    _about_dialog(parent, application)
    # Stop Gtk.LinkButton's default immediate-open behaviour; the dialog probes
    # the candidates and enables only the links that answer.
    return True


def _application_row(parent, application: RankedApplication, path: str,
                     display, on_refresh) -> "object":
    _gdk, Gtk = _gtk()
    row = Gtk.ListBoxRow()
    row.set_activatable(True)
    box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
    box.set_margin_top(8)
    box.set_margin_bottom(8)
    box.set_margin_start(8)
    box.set_margin_end(8)

    # The action belongs on the left of the row, before the icon and text, so
    # the buttons line up and the name column starts at a predictable edge.
    if application.installed and application.usable:
        button = Gtk.Button(label="Open")
        button.add_css_class("suggested-action")
        button.set_size_request(88, -1)
        button.connect("clicked", lambda _button: _open_application(
            parent, application, path, display, on_refresh))
        box.append(button)
    elif application.installed:
        button = Gtk.Button(label="Installed")
        button.set_sensitive(False)
        button.set_size_request(88, -1)
        box.append(button)
    elif application.catalog is not None:
        button = Gtk.Button(label="Install…")
        button.set_size_request(88, -1)
        button.connect("clicked", lambda _button: _install_dialog(parent, application))
        box.append(button)

    icon_name = (application.desktop.icon if application.desktop is not None else "")
    if not icon_name and application.catalog is not None:
        icon_name = application.identifier
    image = Gtk.Image.new_from_icon_name(
        _resolve_icon(display, icon_name, "application-x-executable"))
    image.set_pixel_size(36)
    box.append(image)

    text_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    text_box.set_hexpand(True)
    name_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    name = Gtk.Label(label=application.name)
    name.set_xalign(0)
    name.add_css_class("heading")
    name_row.append(name)
    about_urls = application.about_urls
    about_url = about_urls[0] if about_urls else ""
    if about_url:
        about = Gtk.LinkButton.new_with_label(about_url, "About")
        about.add_css_class("filetype-about")
        about.set_tooltip_text(
            "Check the project page and open the first one that answers:\n"
            + "\n".join(about_urls))
        about.set_valign(Gtk.Align.CENTER)
        about.connect("activate-link",
                      lambda link: _about_clicked(parent, application, link))
        name_row.append(about)
    if application.installed:
        name_row.append(_badge("Installed"))
    elif application.catalog is not None:
        name_row.append(_badge(application.catalog.maturity.title()))
    text_box.append(name_row)
    purpose = Gtk.Label(label=application.purpose)
    purpose.set_xalign(0)
    purpose.set_wrap(True)
    purpose.add_css_class("filetype-dim")
    text_box.append(purpose)
    reason = application.reasons[0] if application.reasons else ""
    if reason:
        reason_label = Gtk.Label(label=reason)
        reason_label.set_xalign(0)
        reason_label.set_wrap(True)
        reason_label.add_css_class("filetype-dim")
        text_box.append(reason_label)
    box.append(text_box)

    row.set_child(box)
    row.connect("activate", lambda _row: (
        _open_application(parent, application, path, display, on_refresh)
        if application.installed and application.usable
        else _install_dialog(parent, application)))
    return row


def _open_application(parent, application: RankedApplication, path: str,
                      display, on_refresh) -> None:
    if application.desktop is None:
        _message(parent, "Not installed",
                 f"{application.name} is not installed. Use the Install button for the command.")
        return
    result = launch_application(application.desktop, path)
    if result.ok:
        parent.close()
    else:
        _message(parent, "The application did not start", result.message)


def _open_as_text(parent, path: str, installed: ApplicationIndex) -> None:
    result = open_as_text(path, installed)
    if result.ok:
        parent.close()
    else:
        _message(parent, "The file could not be opened as text", result.message)


def _add_detail_row(grid, row: int, label_text: str, value_text: str, mono: bool = False) -> None:
    _gdk, Gtk = _gtk()
    label = Gtk.Label(label=label_text)
    label.set_xalign(0)
    label.add_css_class("filetype-dim")
    grid.attach(label, 0, row, 1, 1)
    value = Gtk.Label(label=value_text)
    value.set_xalign(0)
    value.set_wrap(True)
    value.set_selectable(True)
    if mono:
        value.add_css_class("filetype-mono")
    grid.attach(value, 1, row, 1, 1)


def build_window(application, identification: Identification,
                 recommendation: Recommendation, installed: ApplicationIndex,
                 on_refresh=None, self_test: bool = False):
    """Build the chooser window.  Returns the window without running a loop."""
    _gdk, Gtk = _gtk()
    Adw = _adw()
    display = application.get_active_window().get_display() if application.get_active_window() else None
    if display is None:
        try:
            from gi.repository import Gdk
            display = Gdk.Display.get_default()
        except Exception:
            display = None
    window = Gtk.ApplicationWindow(application=application)
    window.set_default_size(820, 700)
    window.set_title(f"Open with — {identification.name}")

    header = Gtk.HeaderBar()
    window.set_titlebar(header)

    scroller = Gtk.ScrolledWindow()
    scroller.set_vexpand(True)
    content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
    for side in ("top", "bottom", "start", "end"):
        getattr(content, f"set_margin_{side}")(18)
    scroller.set_child(content)
    window.set_child(scroller)

    card = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=16)
    card.add_css_class("filetype-card")
    icon = Gtk.Image.new_from_icon_name(
        _resolve_icon(display, _icon_name(identification),
                      identification.generic_icon or "text-x-generic"))
    icon.set_pixel_size(72)
    card.append(icon)
    text = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    text.set_hexpand(True)
    name = Gtk.Label(label=identification.name)
    name.add_css_class("filetype-title")
    name.set_xalign(0)
    name.set_wrap(True)
    text.append(name)
    description = Gtk.Label(label=identification.description)
    description.set_xalign(0)
    description.set_wrap(True)
    text.append(description)
    facts = f"{identification.mime} · {identification.category_label} · {format_size(identification.size)}"
    facts_label = Gtk.Label(label=facts)
    facts_label.set_xalign(0)
    facts_label.add_css_class("filetype-dim")
    facts_label.set_wrap(True)
    text.append(facts_label)
    if identification.is_symlink:
        text.append(Gtk.Label(label="This is a symbolic link."))
    card.append(text)
    content.append(card)

    if recommendation.unhandled:
        warning = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        warning.add_css_class("filetype-warning")
        title = Gtk.Label(label="No installed application can open this file")
        title.set_xalign(0)
        title.add_css_class("heading")
        warning.append(title)
        body = Gtk.Label(label=(
            "Choose an application below, or install one of the suggestions. "
            "The file is safe: nothing has been run or changed."
        ))
        body.set_wrap(True)
        body.set_xalign(0)
        warning.append(body)
        content.append(warning)
    if identification.conflict is not None:
        conflict = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        conflict.add_css_class("filetype-warning")
        title = Gtk.Label(label="The name and the contents disagree")
        title.set_xalign(0)
        title.add_css_class("heading")
        conflict.append(title)
        body = Gtk.Label(label=str(identification.conflict.get("explanation", "")))
        body.set_wrap(True)
        body.set_xalign(0)
        conflict.append(body)
        content.append(conflict)

    section = Gtk.Label(label="Installed applications")
    section.set_xalign(0)
    section.add_css_class("filetype-section")
    content.append(section)
    if recommendation.installed:
        list_box = Gtk.ListBox()
        list_box.set_selection_mode(Gtk.SelectionMode.NONE)
        list_box.add_css_class("boxed-list")
        for app in recommendation.installed:
            list_box.append(_application_row(window, app, str(identification.path),
                                             display, on_refresh))
        content.append(list_box)
    else:
        empty = Gtk.Label(label=(
            "No installed application is registered for this type. "
            "The suggestions below can be installed, or use Open as Text."
        ))
        empty.set_wrap(True)
        empty.set_xalign(0)
        empty.add_css_class("filetype-dim")
        content.append(empty)

    section = Gtk.Label(label="Applications worth installing")
    section.set_xalign(0)
    section.add_css_class("filetype-section")
    content.append(section)
    if recommendation.available:
        list_box = Gtk.ListBox()
        list_box.set_selection_mode(Gtk.SelectionMode.NONE)
        list_box.add_css_class("boxed-list")
        for app in recommendation.available[:12]:
            list_box.append(_application_row(window, app, str(identification.path),
                                             display, on_refresh))
        content.append(list_box)
        if 12 < len(recommendation.available):
            more = Gtk.Label(label=f"{len(recommendation.available) - 12} more suggestion(s) are in the command-line report.")
            more.set_xalign(0)
            more.add_css_class("filetype-dim")
            content.append(more)
    else:
        no_suggestion = Gtk.Label(label=(
            "The catalog has no suggestion for this type. Inspect it, open it as text, "
            "or search the catalog."
        ))
        no_suggestion.set_wrap(True)
        no_suggestion.set_xalign(0)
        no_suggestion.add_css_class("filetype-dim")
        content.append(no_suggestion)

    details = Gtk.Expander(label="How this file was identified")
    grid = Gtk.Grid(column_spacing=14, row_spacing=8)
    grid.set_margin_top(8)
    _add_detail_row(grid, 0, "Detected by", f"{identification.source} ({identification.confidence_label} confidence)")
    _add_detail_row(grid, 1, "libmagic", f"{identification.magic.mime or 'unavailable'} — {identification.magic.description or 'no description'}")
    extension = identification.extension
    _add_detail_row(grid, 2, "Name", f".{extension.suffix} → {extension.mime}" if extension.mime else (f".{extension.suffix} is not a known extension" if extension.suffix else "No extension"))
    _add_detail_row(grid, 3, "Category", identification.category_label)
    _add_detail_row(grid, 4, "Path", str(identification.path), mono=True)
    for index, reason in enumerate(identification.reasons):
        _add_detail_row(grid, 5 + index, "Why", reason)
    details.set_child(grid)
    content.append(details)

    commands = Gtk.Expander(label="Command line")
    command_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
    command_box.set_margin_top(8)
    command_list = [
        f"filetype identify --apps {identification.path}",
        f"filetype apps {identification.path}",
        f"filetype open {identification.path}",
        f"filetype identify --json {identification.path}",
    ]
    for command in command_list:
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        label = Gtk.Label(label=command)
        label.set_xalign(0)
        label.set_selectable(True)
        label.set_hexpand(True)
        label.add_css_class("filetype-mono")
        row.append(label)
        copy = Gtk.Button(label="Copy")
        copy.connect("clicked", lambda _button, text=command: _copy(display, text))
        row.append(copy)
        command_box.append(row)
    commands.set_child(command_box)
    content.append(commands)

    if recommendation.notes:
        notes = Gtk.Expander(label="Notes")
        note_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        note_box.set_margin_top(8)
        for note in recommendation.notes:
            if not note:
                continue
            label = Gtk.Label(label=note)
            label.set_wrap(True)
            label.set_xalign(0)
            note_box.append(label)
        notes.set_child(note_box)
        content.append(notes)

    action = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    action.set_halign(Gtk.Align.END)
    text_button = Gtk.Button(label="Open as Text")
    text_button.connect("clicked", lambda _button: _open_as_text(
        window, str(identification.path), installed))
    action.append(text_button)
    reveal = Gtk.Button(label="Show in Files")
    reveal.connect("clicked", lambda _button: reveal_in_file_manager(str(identification.path)))
    action.append(reveal)
    if recommendation.default is not None and recommendation.default.usable:
        default_button = Gtk.Button(label=f"Open with {recommendation.default.name}")
        default_button.connect("clicked", lambda _button: _open_application(
            window, recommendation.default, str(identification.path), display, on_refresh))
        action.append(default_button)
    else:
        default_button = Gtk.Button(label="Open with Default")
        default_button.connect("clicked", lambda _button: open_default(str(identification.path)))
        action.append(default_button)
    close = Gtk.Button(label="Close")
    close.connect("clicked", lambda _button: window.close())
    action.append(close)
    content.append(action)

    # Escape closes the window, so a user is never trapped in it.
    Gdk = _gdk
    key_controller = Gtk.EventControllerKey()

    def on_key(_controller, keyval, _keycode, _state):
        if keyval == Gdk.KEY_Escape:
            window.close()
            return True
        return False

    key_controller.connect("key-pressed", on_key)
    window.add_controller(key_controller)

    if self_test:
        from gi.repository import GLib
        print("filetype: chooser window built", file=sys.stderr)
        GLib.timeout_add(500, application.quit)
    return window


def _configure_css() -> None:
    _gdk, Gtk = _gtk()
    try:
        from gi.repository import Gdk
        display = Gdk.Display.get_default()
        if display is None:
            return
        provider = Gtk.CssProvider()
        provider.load_from_data(_css().encode("utf-8"))
        Gtk.StyleContext.add_provider_for_display(
            display, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
    except Exception:
        pass


def run(path: str, self_test: bool = False) -> int:
    """Run the chooser as a GTK application."""
    _gdk, Gtk = _gtk()
    Adw = _adw()
    application_class = Adw.Application if Adw is not None else Gtk.Application
    # A distinct id per process keeps GApplication from treating a chooser in
    # another session (or a test under Xvfb) as the same instance and sending
    # it remote activations, which would create invisible duplicate windows.
    application_id = f"io.github.filetype.Chooser.p{os.getpid()}"
    application = application_class(application_id=application_id)
    if Adw is not None:
        try:
            Adw.init()
        except Exception:
            pass
    index = TypeIndex.load()

    if not path:
        message = "A file is needed. Usage: filetype choose FILE"
        print(message, file=sys.stderr)
        return 2

    target = str(Path(path).expanduser())
    try:
        identification, recommendation, installed = load(target, index)
    except Exception as error:
        print(f"filetype: could not inspect {path}: {error}", file=sys.stderr)
        return 1

    windows: dict[str, object] = {}

    def on_activate(app):
        existing = windows.get(target)
        if existing is not None:
            existing.present()
            return
        _configure_css()
        window = build_window(app, identification, recommendation, installed,
                              self_test=self_test)
        windows[target] = window

        def forget(_window):
            windows.pop(target, None)
            return False

        window.connect("close-request", forget)
        window.present()

    try:
        from gi.repository import Gio
        quit_action = Gio.SimpleAction.new("quit", None)
        quit_action.connect("activate", lambda *_args: application.quit())
        application.add_action(quit_action)
        application.set_accels_for_action("app.quit", ["<Primary>q"])
    except Exception:
        pass

    application.connect("activate", on_activate)
    status = application.run([])
    return int(status) if status is not None else 0

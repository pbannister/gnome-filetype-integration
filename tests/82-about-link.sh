#!/bin/sh
#
# Verify the About button exists on application rows, sits beside the
# application name, and opens the grouped About dialog.  The test never
# launches a URI: a test must not open a browser page on the real desktop.
#
# Tier: tool-gated (xvfb-run and GTK4).
set -eu

DIRECTORY_SCRIPT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$DIRECTORY_SCRIPT/.." && pwd)
. "$DIRECTORY_SCRIPT/lib/filetype_env.sh"
. "$DIRECTORY_SCRIPT/lib/test_helpers.sh"
skip_unless_tool python3
skip_unless_tool xvfb-run

python3 - <<'PY' || { echo 'SKIP: missing tool: gtk4'; exit 0; }
import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk
assert Gtk.get_major_version() == 4
PY

filetype_sandbox
trap filetype_cleanup EXIT HUP INT TERM

LIBRARY="$REPOSITORY_ROOT/dataflow.out/build/program/lib/gnome-filetype-integration"
[ -d "$LIBRARY" ] || { echo 'SKIP: missing tool: staged program'; exit 0; }

output=$(PYTHONPATH="$LIBRARY" xvfb-run -a env GDK_BACKEND=x11 \
    python3 - "$FIXTURES/sample.png" <<'PY' 2>&1
import os
import sys
import time
from types import SimpleNamespace

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Gdk", "4.0")
from gi.repository import Gdk, Gio, GLib, Gtk

import filetype_integration.gtk_chooser as chooser
from filetype_integration.gtk_chooser import (PROJECT_PAGES_URL,
                                                PROJECT_REPOSITORY_URL,
                                                _install_dialog, build_window,
                                                load)
from filetype_integration.version import version_string


def walk(widget):
    yield widget
    child = widget.get_first_child()
    while child is not None:
        yield from walk(child)
        child = child.get_next_sibling()


def on_activate(application):
    identification, recommendation, installed = load(sys.argv[1])
    window = build_window(application, identification, recommendation, installed)
    window.present()
    GLib.idle_add(check, window, application, recommendation)


def check(window, application, recommendation):
    links = [widget for widget in walk(window)
             if isinstance(widget, Gtk.Button) and widget.get_label() == "About"]
    assert links, "no About button was built"
    for link in links:
        assert link.get_tooltip_text() is None, "the About button has a tooltip"
    # The install dialog has a Run button and an output view.  Replace the
    # package-manager argv with a harmless command so the test exercises the
    # wiring and the output view without installing anything.
    chooser.install_argv = lambda entry: ["/bin/echo", f"RUN-{entry['method']}"]
    offer = recommendation.available[0]
    dialog = _install_dialog(window, offer)
    run_buttons = [widget for widget in walk(dialog)
                   if isinstance(widget, Gtk.Button) and widget.get_label() == "Run"]
    assert run_buttons, "no Run button in the install dialog"
    output_views = [widget for widget in walk(dialog) if isinstance(widget, Gtk.TextView)]
    assert output_views, "no output view in the install dialog"
    print(f"RUN-BUTTONS {len(run_buttons)}")
    print("OUTPUT-VIEW ok")

    rows = [widget for widget in walk(window) if isinstance(widget, Gtk.ListBoxRow)]
    assert rows, "no application rows"
    for row in rows:
        content = row.get_child()
        assert isinstance(content, Gtk.Box), type(content)
        first = content.get_first_child()
        assert isinstance(first, Gtk.Button), type(first)
        assert first.get_label() in {"Open", "Install…", "Installed"}, first.get_label()
    scheme = Gio.AppInfo.get_default_for_type("x-scheme-handler/https", False)
    assert scheme is not None, "no default https handler for the About links"
    print(f"HTTPS-HANDLER {scheme.get_id()}")
    print(f"ABOUT-LINKS {len(links)}")
    print(f"ROWS {len(rows)}")

    notebooks = [widget for widget in walk(window) if isinstance(widget, Gtk.Notebook)]
    assert len(notebooks) == 1, notebooks
    notebook = notebooks[0]
    labels = [notebook.get_tab_label_text(notebook.get_nth_page(index))
              for index in range(notebook.get_n_pages())]
    assert labels == ["Installed", "Relevant", "About"], labels

    # The About tab starts with the project, version, and project links.
    notebook.set_current_page(2)
    about_page = notebook.get_nth_page(2)
    about_labels = [widget.get_text() for widget in walk(about_page)
                    if isinstance(widget, Gtk.Label) and widget.get_text()]
    assert "Discover Applications…" in about_labels, about_labels
    assert any(version_string() in text for text in about_labels), about_labels
    project_links = [widget for widget in walk(about_page)
                     if isinstance(widget, Gtk.LinkButton)]
    project_uris = {link.get_uri() for link in project_links}
    assert PROJECT_REPOSITORY_URL in project_uris, project_uris
    assert PROJECT_PAGES_URL in project_uris, project_uris
    print("PROJECT-ABOUT ok")

    output_view = output_views[0]
    run_buttons[0].emit("clicked")

    def fake_check(urls, timeout=4.0, max_workers=8, force=False, on_result=None):
        time.sleep(0.4)
        results = {}
        for url in urls:
            result = SimpleNamespace(url=url, ok=True, checked_today=True,
                                     from_cache=False)
            results[url] = result
            if on_result is not None:
                on_result(result)
        return results

    chooser.check_about_urls = fake_check
    links[0].emit("clicked")
    assert notebook.get_current_page() == 2, notebook.get_current_page()
    about_page = notebook.get_nth_page(2)
    about_buttons = [widget for widget in walk(about_page)
                     if isinstance(widget, Gtk.LinkButton)]
    assert about_buttons, "the About tab has no candidate links"
    assert all(button.get_tooltip_text() is None for button in about_buttons), \
        "a candidate link has a tooltip"
    assert all(not button.get_sensitive() for button in about_buttons), \
        "a candidate link was enabled before its HEAD check returned"

    def finish():
        assert all(button.get_sensitive() for button in about_buttons), \
            "a successful candidate link stayed disabled"
        tab_labels = [widget.get_text() for widget in walk(about_page)
                      if isinstance(widget, Gtk.Label) and widget.get_text()]
        for category in ("Project", "Package"):
            assert category in tab_labels, (category, tab_labels)
        display = window.get_display()
        monitor = display.get_primary_monitor() if display is not None else None
        if monitor is None and display is not None:
            monitor = display.get_monitors().get_item(0)
        print(f"ABOUT-SIZE {window.get_width()}x{window.get_height()}")
        if monitor is not None:
            assert window.get_height() <= monitor.get_geometry().height, (
                window.get_height(), monitor.get_geometry().height)
        print("ABOUT-TAB ok")
        text = output_view.get_buffer().get_text(
            output_view.get_buffer().get_start_iter(),
            output_view.get_buffer().get_end_iter(), False)
        assert "RUN-apt" in text, text
        statuses = [widget for widget in walk(dialog) if isinstance(widget, Gtk.Label)
                    and "Finished" in (widget.get_text() or "")]
        assert statuses, "the install status did not report completion"
        print("RUN-OUTPUT ok")
        dialog.close()
        application.quit()
        return False

    GLib.timeout_add(1200, finish)
    return False


application = Gtk.Application(application_id=f"io.github.filetype.AboutTest{os.getpid()}")
application.connect("activate", on_activate)
raise SystemExit(application.run([]))
PY
) || {
    printf '%s\n' "$output" >&2
    echo '82-about-link: the About link test failed' >&2
    exit 1
}

printf '%s\n' "$output" | grep -q '^ABOUT-LINKS ' || {
    printf '%s\n' "$output" >&2
    echo '82-about-link: the About links were not counted' >&2
    exit 1
}
printf '%s\n' "$output" | grep -q '^HTTPS-HANDLER ' || {
    printf '%s\n' "$output" >&2
    echo '82-about-link: no https handler was found' >&2
    exit 1
}
printf '%s\n' "$output" | grep -q '^RUN-BUTTONS [1-9]' || {
    printf '%s\n' "$output" >&2
    echo '82-about-link: the install dialog has no Run button' >&2
    exit 1
}
printf '%s\n' "$output" | grep -q '^OUTPUT-VIEW ok' || {
    printf '%s\n' "$output" >&2
    echo '82-about-link: the install dialog has no output view' >&2
    exit 1
}
printf '%s\n' "$output" | grep -q '^PROJECT-ABOUT ok' || {
    printf '%s\n' "$output" >&2
    echo '82-about-link: the project About tab is incomplete' >&2
    exit 1
}
printf '%s\n' "$output" | grep -q '^ABOUT-TAB ok' || {
    printf '%s\n' "$output" >&2
    echo '82-about-link: the About tab did not show enabled candidates' >&2
    exit 1
}

# A test must never hand a URI to the desktop's real browser.
if grep -R -n 'Gio.AppInfo.launch' "$REPOSITORY_ROOT/tests" --include='*.sh' \
        | grep -v '82-about-link.sh' | grep -q .; then
    echo '82-about-link: a test still launches a URI' >&2
    exit 1
fi

echo '82-about-link: ok'
exit 0

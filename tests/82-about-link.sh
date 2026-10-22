#!/bin/sh
#
# Verify the About link exists on application rows, has a usable URL, and sits
# beside the application name while the action button is on the left.
#
# Tier: tool-gated (xvfb-run, GTK4, and a default https handler).
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
from filetype_integration.gtk_chooser import _install_dialog, build_window, load


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
    links = [widget for widget in walk(window) if isinstance(widget, Gtk.LinkButton)]
    assert links, "no About link was built"
    for link in links:
        assert link.get_label() == "About", link.get_label()
        assert link.get_tooltip_text() is None, "the About link has a tooltip"
        uri = link.get_uri()
        assert uri.startswith("https://"), uri
        assert "." in uri.split("://", 1)[1], uri
        print(f"ABOUT {link.get_label()} {uri}")
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
    assert scheme is not None, "no default https handler for the About link"
    print(f"HTTPS-HANDLER {scheme.get_id()}")
    launched = Gio.AppInfo.launch_default_for_uri("https://example.org/filetype", None)
    assert launched, "the https handler did not accept the link"
    print("HTTPS-LAUNCH ok")
    print(f"ABOUT-LINKS {len(links)}")
    print(f"ROWS {len(rows)}")

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
    links[0].emit("activate-link")

    def toplevels():
        model = Gtk.Window.get_toplevels()
        return [model.get_item(index) for index in range(model.get_n_items())]

    about_windows = [window for window in toplevels()
                     if (window.get_title() or "").startswith("About ")]
    assert about_windows, "clicking About did not open the About dialog"
    about_dialog = about_windows[0]
    about_buttons = [widget for widget in walk(about_dialog)
                     if isinstance(widget, Gtk.LinkButton)]
    assert about_buttons, "the About dialog has no candidate links"
    assert all(button.get_tooltip_text() is None for button in about_buttons), \
        "a candidate link has a tooltip"
    assert all(not button.get_sensitive() for button in about_buttons), \
        "a candidate link was enabled before its HEAD check returned"

    def finish():
        assert all(button.get_sensitive() for button in about_buttons), \
            "a successful candidate link stayed disabled"
        labels = [widget.get_text() for widget in walk(about_dialog)
                  if isinstance(widget, Gtk.Label) and widget.get_text()]
        for category in ("Project", "Package"):
            assert category in labels, (category, labels)
        display = about_dialog.get_display()
        monitor = display.get_primary_monitor() if display is not None else None
        if monitor is None and display is not None:
            monitor = display.get_monitors().get_item(0)
        print(f"ABOUT-SIZE {about_dialog.get_width()}x{about_dialog.get_height()}")
        assert about_dialog.get_height() > 300, about_dialog.get_height()
        if monitor is not None:
            assert about_dialog.get_height() <= monitor.get_geometry().height, (
                about_dialog.get_height(), monitor.get_geometry().height)
        print("ABOUT-DIALOG ok")
        about_dialog.close()
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
printf '%s\n' "$output" | grep -q '^HTTPS-LAUNCH ok' || {
    printf '%s\n' "$output" >&2
    echo '82-about-link: the https handler did not accept the link' >&2
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
printf '%s\n' "$output" | grep -q '^ABOUT-DIALOG ok' || {
    printf '%s\n' "$output" >&2
    echo '82-about-link: the About dialog did not show enabled candidates' >&2
    exit 1
}
printf '%s\n' "$output" | grep -q '^ABOUT About https://' || {
    printf '%s\n' "$output" >&2
    echo '82-about-link: no valid About URI was printed' >&2
    exit 1
}

echo '82-about-link: ok'
exit 0

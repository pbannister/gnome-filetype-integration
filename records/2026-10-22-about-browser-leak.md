# Record: test opened About pages in the real browser

## What happened

The page `https://example.org/test-image-viewer` opened in the real browser
twice during a test run.

Two test actions caused it:

1. `tests/82-about-link.sh` called
   `Gio.AppInfo.launch_default_for_uri("https://example.org/filetype", None)`.
   The sandbox redirected the *desktop entries* to fixture applications, but
   GIO still used the real session's URI handler.
2. The same test emitted `Gtk.LinkButton::activate-link` on the main About
   link. The stock GTK handler opened the link's URI
   (`https://example.org/test-image-viewer`) in addition to our signal handler
   opening the dialog.

The full suite and a direct rerun produced the page twice.

## Fix (applied, verified)

- The main About control is now a plain `Gtk.Button`, not a `Gtk.LinkButton`.
  It has no URI and cannot be opened by a stock handler. Clicking it only opens
  the About dialog.
- Tests never call `Gio.AppInfo.launch_default_for_uri` or emit
  `Gtk.LinkButton::activate-link`.
- The About dialog test builds `_about_dialog` directly and checks the disabled
  and enabled link states with an injected checker.
- `tests/82-about-link.sh` now greps the test directory and fails if any test
  contains `Gio.AppInfo.launch`, excluding the guard itself.
- Candidate links in the dialog remain real `Gtk.LinkButton`s, but only after a
  successful HEAD check, and only a user can click them.

## Verification

- `make test` on 2026-10-22: all 27 test scripts passed.
- The About dialog test still checks grouping, the disabled-before-HEAD state,
  enabled-after-success state, size, and no tooltips.
- No test contains a URI launch call; the guard enforces it.
- The installed copy was not updated, per the owner's manual-install preference.

## Commits

- `6b703cb` fix: stop tests from opening About pages in a browser

# TODO

## Open

* [ ] publish the page set to the homelab site and cut a public release (needs the owner's repository and publishing credentials).
* [ ] widen the catalog beyond the current 169 applications, starting with the least-covered categories (presentation, calendar, contact, subtitle).
* [ ] verify the handler install and the chooser on a second distribution and on a non-GNOME XDG desktop.
* [ ] add a Nautilus test that runs when `python3-nautilus` is present; the current test skips that path.
* [ ] consider a GNOME Shell search provider for launching the chooser without a file.

## Recently Completed

* [x] implement the file type integration end to end (2026-10-22):
    * [x] identify a file from libmagic and the shared-mime-info globs, with a reported conflict and confidence.
    * [x] index 1,943 MIME types and 2,245 extensions on the development machine, including compound extensions and aliases.
    * [x] discover 196 installed desktop applications and resolve defaults from `mimeapps.list` and GIO.
    * [x] curate 169 applications with purpose, maturity, popularity, usefulness, and install hints across 26 categories.
    * [x] build the GTK4/libadwaita chooser with the file facts, installed applications, installable suggestions, install commands, and copyable CLI equivalents.
    * [x] register the handler for every known type, set defaults for the unhandled or broken ones, and reverse both from a manifest.
    * [x] add the optional Nautilus right-click extension and report the missing bindings honestly.
    * [x] add the `filetype` command line with identify, apps, open, scan, handler, types, catalog, doctor, and version.
    * [x] add sandboxed tests, including a GTK window build under Xvfb; `make test` passes.
    * [x] prove that every known MIME type yields at least one installed or suggested application.

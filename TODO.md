# TODO

## Open

* [ ] widen the catalog beyond the current 189 applications, starting with the least-covered categories (presentation, calendar, contact, subtitle).
* [ ] verify the handler install and the chooser on a second distribution and on a non-GNOME XDG desktop.
* [ ] add a Nautilus test that runs when `python3-nautilus` is present; the current test skips that path.
* [ ] consider a GNOME Shell search provider for launching the chooser without a file.

## Recently Completed

* [x] publish the page set to the homelab site (2026-11-20):
    * [x] register `gnome-filetype-integration` in the homelab
          `sources/projects.yaml` (`self_published`, local `pages_source`).
    * [x] refresh the live state, rebuild the page set, and pass the leak gate.
    * [x] publish through the homelab's `make deploy`; the index, the extra
          pages, and the full-text pages answer HTTP 200 with the one homelab
          nav at labs.bannister.us/projects/gnome-filetype-integration/.
    * [x] correct the stale release-pending status in `site.in/index.txt` and
          `README.md`; phase 4 is complete in `PHASES.md`.
* [x] publish a release and make it install with one command (2026-10-23; owner
      instruction):
    * [x] `make release-publish` and `scripts/release-publish.sh` tag the commit
      and create or update the GitHub release.
    * [x] `scripts/install.sh` defaults to the project repository and asset name,
      so the documented `curl … | sh` needs no environment variables; it also
      builds from the source archive when no prebuilt asset matches the machine.
    * [x] `tests/08-release-publish.sh` and `tests/11-release-install.sh` cover
      the publish decisions, the default repository URL, and the handler opt-out.
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

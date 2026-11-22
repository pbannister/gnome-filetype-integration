# TODO

## Open

## Recently Completed

* [x] consider a GNOME Shell search provider (2026-11-22):
    * [x] record the evidence, the options ladder, and the recommendation in
          `documents/14-search-provider-decision.md`; GNOME Shell 50 still
          uses the SearchProvider2 D-Bus mechanism, and `filetype choose`
          currently needs a file path.
    * [x] recommend no provider until someone asks for the flow; if built,
          start with a recent-files provider that activates the existing
          chooser, and verify user-level provider registration first.
* [x] exercise the Nautilus extension when the bindings are present
      (2026-11-22):
    * [x] find the cause of the skip: this host has the Nautilus-4.1 typelib,
          but both the test and the install detection required 4.0.
    * [x] add behavioral assertions to `tests/90-nautilus-extension.sh`:
          menu items, empty selections, activation argv, an installed copy
          equal to the source, and removal on uninstall; the test detects the
          typelibs itself.
    * [x] accept Nautilus 4.1 and 4.0 in `_nautilus_bindings_available`;
          `filetype doctor` now reports `python3-nautilus available` and the
          test runs the install path instead of skipping it.
* [x] verify the handler install and the chooser on a second distribution
      and a non-GNOME XDG desktop (2026-11-20):
    * [x] install the published release in an isolated Fedora 45 container
          with XFCE 4.20, as a non-root user; the digest check passes.
    * [x] verify identification, handler registration, and defaults: 1024
          defaults set, all for types with no installed handler; the XFCE
          handler for `application/x-desktop` is kept.
    * [x] build the chooser window under Xvfb with
          `XDG_CURRENT_DESKTOP=XFCE` for choose and handle.
    * [x] uninstall restores every changed default and removes the entry
          and manifest; the result is recorded in
          `documents/13-portability-verification.md`.
* [x] widen the catalog in the least-covered categories (2026-11-20):
    * [x] add 21 applications (189 → 210): presentation gains Calligra Stage,
          FreeOffice, WPS Office, Impressive, and PDF Presenter Console;
          calendar gains khal, KOrganizer, Osmo, gcalcli, vdirsyncer, and
          icalendar; contact gains KAddressBook, khard, abook, and vobject;
          subtitle gains Subtitle Composer, Gaupol, Subtitle Edit, subliminal,
          srt, and ffsubsync.
    * [x] name the PowerPoint MIME types and extensions in LibreOffice and
          ONLYOFFICE, and the SubRip MIME type in Aegisub, so the core types
          match specifically instead of by category.
    * [x] prove the specific matches with new assertions in
          `tests/30-application-catalog.sh`, written before the data change.
    * [x] replace the hardcoded catalog count in `site.in/index.txt` with the
          `__CATALOG_APPLICATIONS__` placeholder; republish the page set
          through the homelab.
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

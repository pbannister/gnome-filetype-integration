# Decision: GNOME Shell search provider for the chooser — 2026-11-22

Input to: the `TODO.md` consideration item, and to a future task only if the
human chooses to build.
This record recommends; it does not authorize implementation.

## Question

Should the project offer a GNOME Shell search provider that lets a user
launch the chooser from the Overview without first opening a file manager?

## Evidence

- GNOME documents the still-supported mechanism: implement
  `org.gnome.Shell.SearchProvider2` with five D-Bus methods
  (`GetInitialResultSet`, `GetSubsearchResultSet`, `GetResultMetas`,
  `ActivateResult`, `LaunchSearch`), install a `.ini` in
  `$(datadir)/gnome-shell/search-providers/`, and make the service activatable;
  a desktop entry supplies the name and icon. Searching must not visibly open
  the application; a result activation may open it.
  <https://developer.gnome.org/documentation/tutorials/search-provider.html>
- The same tutorial says method handlers should be asynchronous, that the
  Shell shows at most three results per provider, and that GNOME Settings
  controls which providers are enabled. The upstream interface definition is
  at <https://github.com/gNOME/gnome-shell/blob/main/data/org.gnome.ShellSearchProvider2.xml>.
- The GNOME JavaScript guide documents registration for GNOME 45 and later,
  both for applications (D-Bus service) and for Shell extensions (direct
  registration). <https://gjs.guide/extensions/topics/search-provider.html>
- Observed on 2026-11-22: GNOME Shell 50.1 is installed here.
  `filetype choose --help` presents `FILE` as optional, but `command_choose`
  in `sources/filetype_integration/cli.py` refuses to run without a path, so
  "without a file" needs a new source of paths or a new chooser mode.
- Observed on 2026-11-22: no search-provider source, desktop entry, or
  registration exists in this repository.
- `unverified`: whether GNOME Shell 50 scans a user-level provider directory
  under `$XDG_DATA_HOME`; the primary documentation names
  `$(datadir)/gnome-shell/search-providers` only. This must be checked
  empirically before any provider is built.
- `unverified`: whether a recent-files source returns enough useful matches
  for a typical query. It was not trialled here.

## Options ladder, cheapest first

- Rung 0 — No provider. The Nautilus right-click action, Open With, and the
  command line already reach the chooser with a file path. Cost: none. Buys:
  nothing new, and keeps the project desktop-agnostic.
- Rung 1 — A small D-Bus service implementing `SearchProvider2` that searches
  the user's recent files by name and activates `filetype choose <path>` for
  a selected result. Reuses the existing chooser unchanged; installs under
  XDG directories and is reversed with the manifest like the handler. Buys:
  the Overview-to-chooser flow with no new chooser UI. Cost: one service
  file, a provider `.ini`, a desktop entry, and sandboxed D-Bus tests.
- Rung 2 — Rung 1 plus a bounded filename scan of a chosen local directory,
  so files absent from the recent list still match. Buys: wider coverage.
  Cost: per-keystroke local scanning, error handling, and a privacy decision
  about which directories may be searched.
- Rung 3 — A no-file mode in the chooser itself (a GTK file picker) with the
  provider returning a single "choose a file" result. Buys: works with no
  recent files and on any desktop. Cost: a new UI path in portable code and
  its tests, for a GNOME-specific entry point.
- Rung 4 — A GNOME Shell extension registering the provider in JavaScript.
  Buys: no separate service file. Cost: a second language and packaging path,
  extension review, and desktop-specific maintenance; contrary to the
  project's XDG-based design.

## Recommendation

Stay at Rung 0 until someone asks for the flow. If the human wants it, choose
Rung 1 and verify the `unverified` provider-directory question first.
Do not pay for Rungs 2–4 unless Rung 1 proves insufficient. Lower rungs are
exhausted before the higher ones.

## Consequences of Rung 1

- The provider must be optional: its absence must not affect Open With, the
  command line, or non-GNOME desktops, and uninstall must restore the state.
- Searching stays local: no telemetry and no network request, consistent with
  `FILETYPE-R018`; result names cross the local D-Bus boundary to the Shell.
- Search queries must not open a window; only `ActivateResult` launches the
  chooser, with one file path as the argument.
- Tests use a temporary XDG tree and a session bus; the live Shell is never
  restarted in `make test`. A live-shell check would be a separate,
  explicitly run live-state verification.
- Only GNOME Shell 50 is evidenced here; support for other versions is
  `unverified` and needs its own check.

## What reopens this decision

- A user asks for the Overview flow, or the Nautilus action proves insufficient.
- Rung 1's file source yields too few matches in practice.
- GNOME replaces or deprecates `SearchProvider2`.
- A proposed implementation would need network access or writes outside XDG
  directories; that rung is dropped rather than adapted.

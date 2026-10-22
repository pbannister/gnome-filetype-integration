# Record: grouped About list, daily history, and Helix install command

## Outcome

- Helix's Ubuntu package is recorded as `hx`, so the install hint is
  `sudo apt install hx`.
- The About link opens a dialog rather than opening one URL immediately. The
  dialog groups candidates as Project, Repository, Documentation, Reference,
  Community, Store, and Package, preserving relevance order inside each group.
- Every candidate link starts disabled. The dialog probes the list concurrently
  with short HEAD requests (one-byte GET fallback) and enables a link only after
  its site answers.
- A site is visited at most once per local day. The visit date, time, status,
  and success are recorded in
  `$XDG_CACHE_HOME/gnome-filetype-integration/about-sites.json`.
- `filetype about-history` lists the recorded visits; `--clear` forgets them.
- Package search pages are gone from the candidate builder. They return HTTP
  200 even with no result, which is how Helix landed on an empty Debian search.
  Direct tracker, sources, Launchpad, and Repology pages replace them.

## Decisions

- Keep the daily history in the cache directory, not the project tree or user
  data. It is derived state and can be cleared at any time.
- Treat a result recorded earlier the same day as already checked. A link whose
  site answered is enabled from that record; a failed one stays disabled until
  the next day.
- Run the HEAD checks on a bounded thread pool (eight workers) and update the
  window through `GLib.idle_add`.
- Do not use package search pages at all. The user's rule was to introspect them
  if included; excluding them removes the false-positive class entirely.

## Verification

- `make test` on 2026-10-22: all 27 test scripts passed.
- `tests/41-about-history` verifies:
  - visit history records the date, status, and success;
  - a second check on the same day makes no request;
  - a yesterday-dated record is rechecked;
  - four 0.4-second checks finish in under 1.2 seconds, proving concurrency;
  - grouping gives Project, Repository, Documentation, Community, Package in
    order for Helix.
- `tests/82-about-link` opens the About dialog, asserts every candidate link is
  initially disabled, then asserts they enable after the injected checks.
- `tests/30-application-catalog` asserts Helix's command is
  `sudo apt install hx`.
- `tests/51-about-live` passes for 21 applications, including Helix.
- The full live audit of 169 catalog applications found at least one reachable
  candidate for every application.

## Current state / next steps

The source and tests are complete. The user rejected the privileged `make
install` needed to update the existing `~/.local` install, so the installed copy
still reports `2026-10-22-master-e75b26f (build 86)`. Run `make install` from
the project checkout to apply this change to the installed copy.

## Commits

- `e92e66e` feat: show grouped About candidates with daily checks

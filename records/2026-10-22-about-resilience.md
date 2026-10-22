# Record: About resilience for renamed applications

## Outcome

Clicking About on **LibreOffice 26.2 Calc** produced one candidate,
`https://packages.ubuntu.com/search?keywords=libreoffice.calc`, and it did not
answer. The snap desktop entry is named `libreoffice_calc.desktop` with the
display name "LibreOffice 26.2 Calc"; neither matched the catalog's
`org.libreoffice.LibreOffice` entry, so the project page and Flathub were never
offered.

The catalog identity match now accepts a version or edition suffix: an
installed name that starts with the catalog name (or the reverse) is the same
application. "LibreOffice 26.2 Calc" therefore uses the LibreOffice catalog
entry, and its first candidate is `https://www.libreoffice.org/`.

The About candidate builder now always produces alternatives:

- project/AppStream page;
- catalog `homepage`;
- vendor URL;
- Flathub;
- Snapcraft;
- Ubuntu package page;
- Debian package page;
- Debian tracker;
- distribution package names derived from the executable and desktop id;
- Flathub and Snapcraft search pages.

The chooser probes at most the first six, in order, and opens the first that
answers.

## Decisions

- Match a renamed desktop application by a prefix with a word boundary, not by
  shared words. A single shared word was too broad: "Test Python Editor" must
  not become the Python catalog entry.
- Keep generic search and package pages as last-resort candidates. They are
  less specific than a project page but are a useful alternative when a
  project page disappears.
- Reduce a packaged executable such as `/snap/bin/libreoffice.calc` to
  `libreoffice-calc` and also keep the original name, because distributions
  disagree about the separator.
- Cap probing at six candidates so a click remains quick even when several
  sites are down.

## Verification

- `make test` on 2026-10-22: all 26 test scripts passed.
- `tests/40-about-links` now checks every catalog application has at least two
  structurally valid, unique candidates, and reproduces the renamed
  LibreOffice snap case.
- `tests/51-about-live` (`FILETYPE_LIVE=1`) audits a sample of real project
  pages and passes for all 20 applications.
- A full live audit of all 169 catalog applications found at least one
  reachable candidate for every application; many fell back from a project page
  to the Debian package page.
- The installed copy was updated and reports
  `2026-10-22-master-3a5fd96 (build 72)`. For the real snap LibreOffice Calc,
  the installed package now builds 14 candidates and the first,
  `https://www.libreoffice.org/`, answers `True`.
- A repeated handler install no longer reports its own default as a broken
  default; `defaults_set` is 0 on refresh.

## Commits

- `877a9b8` fix: make About candidates resilient to renamed applications
- `3a5fd96` fix: treat the chooser's own default as installed on refresh

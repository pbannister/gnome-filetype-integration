# Record: Debian tracker homepages and About window size

## Outcome

- The About window height follows its content instead of a fixed 620 pixels.
  It uses the scroller's natural height and caps it at 82% of the monitor; the
  test dialog measured `760x582` under the 1100x800 Xvfb screen.
- Missing project pages are also taken from Debian tracker package pages. The
  tracker's `homepage` link is the same upstream URL shown under
  `packages.debian.org` "External Resources", and is usually the link found in
  the source README.
- `scripts/catalog-enrich-debian.sh` does that enrichment explicitly:
  it checks entries with an apt package and no homepage, fetches
  `https://tracker.debian.org/pkg/<package>`, and records the homepage.
- The Debian pass found 79 homepages for 83 candidates. Four remaining
  applications were filled from their project pages: coreutils, HDFView, QCAD,
  and Typst. All 169 catalog applications now have a project homepage.
- csvkit now records `https://github.com/wireservice/csvkit` as its homepage and
  `https://csvkit.readthedocs.io/` as a reference page, so the About list does
  not stop at a package page.

## Decisions

- Parse the visible tracker link (`title="upstream web homepage"` and the
  `homepage` anchor) rather than a suite-specific Debian package URL, which is
  brittle and returns an anti-bot page to a plain client.
- Keep Flathub and Debian enrichment as explicit maintenance commands; neither
  runs in `make build` or `make test`.
- Do not add package search pages. The direct tracker/sources/Launchpad/
  Repology pages are the package fallback.

## Verification

- `make test` on 2026-10-22: all 27 test scripts passed.
- `tests/40-about-links`:
  - extracts a Debian tracker homepage;
  - asserts csvkit's GitHub homepage and ReadTheDocs reference come before its
    package pages;
  - asserts every catalog application still has at least two candidates and no
    search page.
- `tests/82-about-link` asserts the About dialog height is above 300 pixels and
  no taller than the monitor; it measured `760x582`.
- Full live audit: all 169 catalog applications have a reachable candidate
  among the first four; the 21-application live audit passes.
- Installed copy was not changed, per the owner's manual-install preference.
  Run `make install` in the checkout to apply it.

## Commits

- `2c6d4ec` feat: size About to content and use Debian tracker homepages

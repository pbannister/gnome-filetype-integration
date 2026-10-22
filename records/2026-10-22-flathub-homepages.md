# Record: Flathub project pages and About tooltip removal

## Outcome

- The on-hover tooltip on the About link is gone, and candidate links in the
  About dialog no longer carry URL tooltips. The URL is already visible in the
  list.
- A Flathub application page names the upstream project under "Project
  Website". `scripts/catalog-enrich-flathub.sh` fetches those pages explicitly
  and fills a missing catalog `homepage` from that link. It is a maintenance
  command, not part of `make build` or `make test`.
- The enrichment added 30 project pages. Of the 81 catalog applications with a
  Flatpak id, 79 now have a homepage; `org.f3d.F3D` and `org.gnome.Meld` do not
  expose a Project Website link and keep Flathub as their primary store page.
- GNU Emacs now uses `https://www.gnu.org/software/emacs` before its Flathub
  page; the same applies to the other enriched applications.

## Decisions

- Parse both the visible "Project Website" link and the embedded JSON
  `homepage` field; either is enough.
- Never overwrite a curated homepage with a Flathub one. Enrichment only fills
  an empty `homepage`.
- Keep enrichment out of the portable test suite because it needs the network.
  The parser and the Emacs result are tested offline.
- Prefer the project page over Flathub in the About order; Flathub remains the
  store entry and a fallback when the project page is unreachable.

## Verification

- `make test` on 2026-10-22: all 27 test scripts passed.
- `tests/40-about-links`:
  - extracts the visible and embedded forms of the Flathub project link;
  - asserts GNU Emacs uses its GNU project page before Flathub;
  - still asserts every catalog application has at least two structurally
    valid candidates and no package search pages.
- `tests/82-about-link` asserts the About link and dialog links have no
  tooltips, and still checks disabled-until-HEAD and grouping.
- Live audit: 21/21 sampled applications pass.
- Installed copy was **not** updated, per the owner's manual-install preference;
  run `make install` in the checkout to apply it.

## Commits

- `3ae7926` feat: enrich homepages from Flathub and group About probes

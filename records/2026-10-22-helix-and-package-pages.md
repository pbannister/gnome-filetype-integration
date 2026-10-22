# Record: Helix About pages and package-search removal

## Why Helix fell through

The Helix catalog entry had only `apt: helix`. It had no homepage, repository,
documentation, or reference pages, and no AppStream homepage was available for
the installed entry. The candidate builder therefore fell back to distribution
package **search** pages. A search page answers HTTP 200 even when it finds no
package, so the About probe treated an empty Debian search as a live page.

## Could better links have been found?

Yes. The GitHub repository is the strongest discovery lead: it usually names the
canonical website and documentation. Helix now records:

- homepage: `https://helix-editor.com/`
- repository: `https://github.com/helix-editor/helix`
- documentation: `https://docs.helix-editor.com/`
- community: `https://www.reddit.com/r/HelixEditor/`

They appear in that order before any distribution page.

## Fix (applied, verified)

- Removed every package **search** page from the candidate builder. A search
  result is not evidence that the application was found.
- Replaced them with direct pages: Debian tracker, Debian sources, Launchpad
  Ubuntu source, and Repology. These describe a package or fail visibly.
- Added homepages and reference pages for ten applications that previously had
  only a Flathub or vendor URL, so every catalog application still has at least
  two candidates.
- The catalog `about` list now carries repository, documentation, and community
  links where they are known.

## Verification

- `make test` on 2026-10-22: all 26 test scripts passed.
- `tests/40-about-links` asserts:
  - Helix's first four candidates are homepage, GitHub, docs, and Reddit;
  - no catalog application has a URL containing `/search?` or `search?q=`;
  - every catalog application has at least two unique, structurally valid
    candidates.
- `tests/51-about-live` now includes Helix and passes for all 21 sampled
  applications.
- A full live audit of all 169 catalog applications found a reachable
  candidate among the first four for every application.
- Installed copy: `2026-10-22-master-e75b26f (build 86)`.
- Installed Helix probes: homepage, GitHub, docs, and Reddit all `True`; the
  chooser opens `https://helix-editor.com/`.

## Commits

- `e75b26f` feat: prefer project and repository pages over package searches

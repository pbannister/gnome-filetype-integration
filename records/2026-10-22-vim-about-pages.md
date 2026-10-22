# Record: Vim About pages

## Why the better alternatives were missing

The catalog entry for Vim had no `homepage`, and Vim/GVim had no AppStream
homepage. The installed GVim entry also did not match the catalog entry: its
desktop id is `gvim.desktop`, its name is "GVim", and its executable is `gvim`,
while the catalog said `vim`. Without a catalog match, the candidate builder had
only the executable name to work with, so it produced Ubuntu and Debian package
**search** pages for `gvim`. The Debian search page answered, so the About
probe accepted it; the page is not a useful description of Vim, and the user's
browser request ended up as `...keywords=gvim&pow_referer=`.

The Wikipedia and GitHub pages were not candidates because the catalog had no
field for reference pages. The builder only knew AppStream, install hints, and
package pages.

## Fix (applied, verified)

- Vim now records:
  - `homepage`: `https://www.vim.org/`
  - `about`: the Wikipedia article and `https://github.com/vim/vim`
  - `desktop_ids`: `vim.desktop` and `gvim.desktop`, so GVim uses the same
    catalog entry.
- The catalog schema gained an optional `about` list of reference URLs.
- Candidate order is now project page, curated reference pages, vendor page,
  Flathub, Snapcraft, distribution package pages, tracker, and search pages.
- GIMP gained the same kind of reference entries (Wikipedia and its GitLab
  repository) so the schema demonstrates more than one application.

## Verification

- `make test` on 2026-10-22: all 26 test scripts passed.
- `tests/40-about-links` asserts that GVim matches the Vim catalog entry and
  that the first three candidates are vim.org, the Wikipedia article, and the
  GitHub repository, before any package page.
- Installed copy: `2026-10-22-master-ac71faa (build 82)`.
- Live probe of the installed copy:
  - `https://www.vim.org/` -> True
  - `https://en.wikipedia.org/wiki/Vim_(text_editor)` -> True
  - `https://github.com/vim/vim` -> True
- The opt-in live audit still passes for its 20-application sample.

## Commits

- `ac71faa` fix: give Vim project and reference About pages

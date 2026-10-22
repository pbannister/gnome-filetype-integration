# Record: chooser refinement

## Outcome

The application rows in the File Type Chooser now put the per-application action
button on the left, before the icon and the text. Each row has an **About**
link beside the application name. The link resolves to the project page
recorded by AppStream for an installed application; for a catalog application
that is not installed it resolves to the vendor page, the Flathub page, the
Snapcraft page, or the distribution package page.

A mismatch between the bytes and the name is still reported as a conflict, and
the About link does not change the identified type or the ranking.

## Decisions

- Treat AppStream metadata (`/usr/share/metainfo`, `/usr/share/appdata`, and the
  XDG equivalents) as the best local source for a project page. It is read
  lazily and cached, so a window that never asks for a URL does not pay for the
  scan.
- Fall back in a fixed order: AppStream homepage, vendor URL, Flathub,
  Snapcraft, then the distribution package search. Every fallback describes the
  application; none is a generic web search.
- Keep the link inside the application row rather than a separate details pane,
  so the action and the description are visible together.
- Guard the test sandbox: `tests/lib/filetype_env.sh` now refuses to run when
  `HOME` or the XDG directories are not under the temporary test root. This
  prevents a repeat of the accidental real-home install found during review.

## Verification

- `make test` on 2026-10-22: all 23 test scripts passed, including the new
  AppStream homepage assertions and the GTK window build under Xvfb.
- The fixture AppStream entry resolves to `https://example.org/test-image-viewer`;
  the GIMP catalog entry resolves to its Flathub page.
- The live desktop was restored after the accidental install: the handler
  desktop entry, icon, launcher, manifest, and `mimeapps.list` changes are
  gone, and `gio mime` reports the original defaults.

## Commits

- `69c7988` feat: put the row action left and add an About link

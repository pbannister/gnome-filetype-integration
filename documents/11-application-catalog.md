# The Application Catalog

The catalog answers a second question — *what could open this file?* — for
applications that are **not installed**. Installed applications are discovered
from the desktop, so the catalog does not duplicate them; it adds the
applications worth offering when the desktop has nothing.

The shipped data is `sources/filetype_integration/data/application-catalog.json`.
It is version-controlled, validated by `filetype catalog validate`, and checked
by `make test`.

## Why curate instead of scrape

A package index knows package names, not *what an application is for*. A ranking
needs a purpose sentence and a judgement about maturity and usefulness that a
package description rarely gives. The catalog is small enough to review and
specific enough to be useful. It is not a package manager: every install hint
is a starting point, and a distribution may name or version the package
differently.

The sources are the projects' own documentation and homepages, distribution
package indexes, and Flathub application IDs. Package names were checked on
Ubuntu 26.04 (2026-10-22); Flatpak IDs are the Flathub application IDs. The
catalog carries no licence or download URL requirement: it never downloads an
application, it prints the command the user's package manager already knows.

## Schema

```json
{
  "id": "org.gimp.GIMP",
  "name": "GIMP",
  "purpose": "Raster image editor for retouching, composition, and conversion.",
  "kind": "gui",
  "maturity": "mature",
  "popularity": 95,
  "usefulness": "primary",
  "handles": {
    "mime": ["image/png", "image/jpeg"],
    "extensions": ["xcf", "psd"],
    "categories": ["image", "drawing"]
  },
  "install": {
    "apt": "gimp",
    "flatpak": "org.gimp.GIMP"
  },
  "homepage": "https://www.gimp.org/",
  "desktop_ids": ["gimp.desktop"],
  "binary": "gimp",
  "notes": ""
}
```

- `id` — a stable identifier, ideally a reverse-DNS application ID.
- `name` — the name a person sees.
- `purpose` — one sentence, written for someone who does not know the project.
- `kind` — `gui` or `cli`.
- `maturity` — `mature`, `stable`, `beta`, `experimental`, or `legacy`.
- `popularity` — 0 to 100, an editorial estimate.
- `usefulness` — `primary`, `general`, `specialized`, `companion`, or
  `fallback`.
- `handles` — at least one MIME type, extension, or category. MIME patterns may
  end in `/*` for a family. Extensions omit the leading dot.
- `install` — at least one of `apt`, `flatpak`, `snap`, or `url`. A `url` is a
  vendor download page, not a direct binary.
- `homepage` — optional; the project page shown first by the About link. The
  About candidates are built in this order: AppStream homepage, `homepage`,
  `install.url`, Flathub, Snapcraft, and the distribution package page. On click
  the chooser probes them with a short HEAD request (one-byte GET fallback) and
  opens the first that answers.
- `desktop_ids` — optional; used to notice that a catalog application is
  already installed but not registered for this type.
- `binary` — optional; used to notice a command-line application on `PATH`.
- `notes` — optional caution or context.

## What the estimates mean

### Maturity

| Value | Meaning |
| ----- | ------- |
| `mature` | Long-lived, widely used, stable interfaces; the default choice. |
| `stable` | Released and dependable, but younger or narrower than the mature group. |
| `beta` | Usable, still changing, may lose data or formats. |
| `experimental` | Interesting, not for a file someone needs to keep. |
| `legacy` | Still works, but maintained slowly or superseded. |

Maturity follows the upstream project's own release status and the packaging
reality on a current distribution. It is not a security audit.

### Popularity

A 0–100 editorial estimate of how widely the application is used, not a count
of installs. It exists to break ties between applications that handle the same
type equally well: a household name should appear before an obscure equivalent.
It is deliberately coarse; a difference of five points means little.

### Usefulness

Usefulness is relative to the file kind, not a global rank:

- `primary` — a natural first choice for most of the kinds it handles.
- `general` — a good all-purpose choice, often one of several.
- `specialized` — the right tool for a narrower job, not the default.
- `companion` — useful alongside another application, not alone.
- `fallback` — better than nothing when nothing else matches.

A specialized RAW developer is more useful for a `.cr2` than a general image
viewer, even though the viewer is more popular overall. The ranking uses the
match specificity first, then these weights.

## How ranking uses the catalog

1. Installed applications are scored first: default, then exact type, then
   inherited type; an unavailable program is demoted.
2. A catalog application that is installed but not registered for this type is
   moved into the installed list, with that fact stated.
3. Remaining catalog matches are scored by match specificity (exact MIME,
   family, extension, category), usefulness, maturity, popularity, and whether
   the application is graphical.
4. Results are split into installed and available, so the window can say "you
   can open it now" before "you could install this".

The weights are in `sources/filetype_integration/application_catalog.py`;
`MATURITY_WEIGHT`, `USEFULNESS_WEIGHT`, and `KIND_WEIGHT` are the knobs.

## Coverage

At build time, `scripts/program-build.sh` writes
`dataflow.out/catalog-stats.json` with the MIME type count, the extension count,
the catalog size, and the number of known types without an installed handler.
The build fails if any known type has no installed or suggested application.

The catalog's categories are the same categories the identifier assigns:
directory, text, code, document, spreadsheet, presentation, drawing, image,
audio, video, font, archive, package, executable, database, data, model, CAD,
disk image, ebook, email, calendar, contact, subtitle, binary, web.

## Adding an application

1. Add one object to `applications` in the JSON.
2. Give it a purpose, a maturity, a popularity, a usefulness, at least one
   handle, and at least one install hint.
3. Run `filetype catalog validate` and `make test`.
4. If it handles a new category or MIME family, add the category to the
   coverage test's expectations only when it is a new project category.

Duplicate identifiers and duplicate `(id)` entries are refused. A malformed
entry names itself in the error, so a bad edit does not take the tool down.

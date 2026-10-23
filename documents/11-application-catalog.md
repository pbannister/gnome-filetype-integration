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
package indexes, and Flathub application IDs. A Flathub page that names a
"Project Website" and a Debian tracker page's "upstream web homepage" link are
used to fill a missing `homepage`. `scripts/catalog-enrich-flathub.sh` and
`scripts/catalog-enrich-debian.sh` perform that enrichment explicitly; neither
is part of the portable build. Package names were checked on
Ubuntu 26.04 (2026-10-22); Flatpak IDs are the Flathub application IDs. The
catalog carries no licence or download URL requirement: it never downloads an
application, it prints the command the user's package manager already knows.

## Matching

A MIME type or extension match is specific. A category match is the broader
fallback. For a package or AI format, the broad category adds nothing when a
specific match exists: Flatpak is not offered for an AppImage merely because
both are packages, and PyTorch is not offered for a GGUF file merely because
both are AI models. Other categories stay as a fallback, because a generic
image or document tool may still open a type that another application names
exactly.

A Flatpak-hosted desktop entry runs through `/usr/bin/flatpak`. That launcher
is not the application, so it must not identify the Flatpak tool as installed
for the hosted application's file.

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
  "about": [
    "https://en.wikipedia.org/wiki/GIMP",
    "https://github.com/GNOME/gimp"
  ],
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
- `homepage` — optional; the project page shown first by the About link.
- `about` — optional extra reference pages (for example Wikipedia and the
  source repository), used after `homepage` and before package pages.
- The About candidates are built in this order: a catalog `homepage` (or, when
  it has none, the installed application's AppStream homepage), `about`,
  `install.url`, Flathub, Snapcraft, and direct package pages
  (`tracker.debian.org`, `sources.debian.org`, Launchpad, Repology). The
  catalog page is reviewed here; AppStream metadata comes from the installed
  package and can be stale. Package pages are guessed only for an uncataloged
  application: a program under a system bin directory, or a simple desktop id.
  An AppImage path and a reverse-DNS desktop id are not package names.
  Package search pages are not used: a search page answers HTTP 200 even when
  it finds nothing, which makes it a false positive. On click the chooser shows
  the candidates grouped by category, keeps every link disabled, probes them
  concurrently with short HEAD requests (one-byte GET fallback), and enables
  only the links that answer. Each site is visited at most once per local day;
  `filetype about-history` shows the recorded date, result, and status.
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
3. Remaining catalog matches are ordered first by match specificity (exact
   MIME, wildcard family, direct extension, related extension family, ancestor
   type, category), and only within the same specificity band by usefulness,
   maturity, popularity, installation state, and whether the application is
   graphical. A direct extension always precedes a generic ancestor such as
   `text/plain`.
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
audio, video, font, archive, package, executable, database, data, model, AI
model, CAD, disk image, ebook, email, calendar, contact, subtitle, binary, web.

The shared MIME database does not know the newer model formats, so the index
adds them as built-in types: `application/x-gguf` (`.gguf`),
`application/x-ggml` (`.ggml`), `application/x-safetensors`
(`.safetensors`), `application/x-onnx` (`.onnx`), `application/x-tflite`
(`.tflite`), `application/x-mlmodel` (`.mlmodel`), `application/x-keras`
(`.keras`), `application/x-pytorch` (`.pth`), and
`application/x-torch-checkpoint` (`.ckpt`). Their extensions are specific
enough to name the type. `.pt`, `.bin`, `.pkl`, `.joblib`, `.npy`, and `.h5`
stay with their existing generic or unrelated types, because the name alone
cannot tell a model from another use of the extension.

## Adding an application

1. Add one object to `applications` in the JSON.
2. Give it a purpose, a maturity, a popularity, a usefulness, at least one
   handle, and at least one install hint.
3. Run `filetype catalog validate` and `make test`.
4. If it handles a new category or MIME family, add the category to the
   coverage test's expectations only when it is a new project category.

Duplicate identifiers and duplicate `(id)` entries are refused. A malformed
entry names itself in the error, so a bad edit does not take the tool down.

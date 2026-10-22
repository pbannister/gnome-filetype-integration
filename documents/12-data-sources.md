# Data Sources

The tool reads local databases rather than shipping a copy of them. This
document records what each source contributes, where it comes from, and how
fresh it is.

## MIME types and extensions

| Source | Path or URL | Used for |
| ------ | ----------- | -------- |
| shared-mime-info | `$XDG_DATA_DIRS/*/mime/globs2`, `aliases`, `subclasses`, `packages/*.xml`; <https://gitlab.freedesktop.org/xdg/shared-mime-info> | globs, descriptions, icons, aliases, subclass edges |
| media-types / mime.types | `/etc/mime.types`; <https://packages.debian.org/media-types> | extensions the desktop database omits, and a second opinion |
| IANA media types | <https://www.iana.org/assignments/media-types/media-types.xhtml> | the registry the type names ultimately come from; read indirectly through the local databases |
| libmagic | `file` and `/usr/share/misc/magic.mgc`; <https://www.darwinsys.com/file/> | content identification |

The MIME index is rebuilt from these files on every run. On the development
machine (Ubuntu 26.04, 2026-10-22) it covers 1,943 types and 2,245 extensions
across 1,303 shared-mime-info globs and the `mime.types` additions. The
fixture tree under `dataflow.in/mime/` mirrors the layout so tests do not
depend on the host's database.

## Installed applications

| Source | Path | Used for |
| ------ | ---- | -------- |
| desktop entries | `$XDG_DATA_HOME/applications`, `$XDG_DATA_DIRS/*/applications` | names, comments, `Exec`, `MimeType`, terminal flag, visibility |
| MIME defaults | `$XDG_CONFIG_HOME/mimeapps.list`, `$XDG_CONFIG_DIRS/mimeapps.list`, the data-directory equivalents | the current default and the registered handlers |
| GIO | `Gio.AppInfo` | a second resolution of the default when the files do not name one |
| Flatpak exports | `$XDG_DATA_DIRS/flatpak/exports/share/applications` | installed Flatpak applications |
| Flathub application pages | `https://flathub.org/apps/<id>` | project website for a catalog entry with a Flatpak id |
| Debian tracker pages | `https://tracker.debian.org/pkg/<package>` | upstream homepage for a catalog entry with an apt package; often the link also found in the source README |

On the development machine 196 installed entries were found and 581 MIME types
had at least one registered handler. This is host state, not project data.

## The curated catalog

The catalog is hand-curated from the projects' documentation and homepages,
distribution package indexes, and Flathub. Package names were checked on
Ubuntu 26.04 on 2026-10-22; Flatpak IDs are the Flathub application IDs. The
catalog does not download anything and does not check a package exists at run
time: it prints the command the user's package manager already understands.

The scale and schema are in `documents/11-application-catalog.md`.

## What is deliberately not used

- No web service, search API, or telemetry endpoint. Identification itself makes
  no network request; a downloaded file type should not require an upload to
  identify. The one exception is the About link the user clicks: it probes each
  candidate site with a short HEAD or one-byte GET at most once per day, and
  sends no file data. The visit date, result, and status are recorded for
  `filetype about-history`.
- No filename-only lookup. The name is one witness, never the only one when
  the bytes are specific.
- No package-manager integration beyond printing a command. Installing an
  application remains the user's action, through their own package manager.

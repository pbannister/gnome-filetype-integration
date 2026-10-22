# GNOME File Type Integration

Intelligent handling of every known file type on Linux.

A downloaded file whose type has no installed application is dead weight: the
desktop shows an icon, double-click does nothing useful, and the only advice is
"install something". This project identifies the file from its bytes and its
name, explains the evidence, and offers a ranked list of applications that can
consume it — installed applications first, then the ones worth installing,
with the package command for each.

The same work is available in four places:

- **Double-click** a file with no working handler opens the File Type Chooser.
- **Right-click** any file in Nautilus offers *Choose Application…* and
  *Inspect File Type* when the Nautilus Python bindings are installed.
- **Open With** lists the chooser for every known type, even when a working
  handler already exists.
- **`filetype`** on the command line carries every capability, with stable JSON.

**Status: implemented and tested** (2026-10-22). The identifier, the MIME
index, the desktop discovery, the catalog, the chooser, the handler install and
uninstall, and the command line are built. The test suite runs with
`make test`; the GTK window is exercised under Xvfb. The page set and a public
release are pending; see `PHASES.md` and `TODO.md`.

## The problem, in one example

A `.step` CAD file arrives on a machine without FreeCAD. `file` says
`text/plain`; the name says `model/step`, a type the MIME database knows but the
desktop has no handler for. A stock GNOME desktop offers nothing. With this
project installed, double-click opens a window that says:

- the file is a *STEP 3D model* (`model/step`);
- the name was the decisive evidence, because the bytes are only text;
- no installed application can open it;
- these applications could, why each is suggested, and the exact install
  command for each;
- the equivalent `filetype identify`, `filetype apps`, and `filetype open`
  commands, with a copy button.

The file is never uploaded, executed, or modified.

## Installing

From a checkout:

```sh
make build          # stage the program and its build-time version
make test           # the sandboxed test suite
make install        # install into $HOME/.local, then register the handler
```

`PREFIX` installs elsewhere. `FILETYPE_INTEGRATION_NO_HANDLER=1` installs the
tools and registers nothing; `filetype handler install` remains available at
any time and can be reversed with `filetype handler uninstall`.

A release tarball can be installed the same way:

```sh
curl -fsSL https://raw.githubusercontent.com/pbannister/gnome-filetype-integration/master/scripts/install.sh | sh
```

The installer checks the download against the release's `SHA256SUMS`, installs
under `$HOME/.local` (or `PREFIX`), and then runs the handler registration.
The registration writes only under `$XDG_DATA_HOME`, `$XDG_CONFIG_HOME`, and
the temporary directory; it never needs root.

## Commands

| Command | Purpose |
| ------- | ------- |
| `filetype identify FILE…` | identify files and list the applications that can open them |
| `filetype identify --apps FILE` | also list the applications worth installing |
| `filetype identify --json FILE` | the same facts as one JSON document |
| `filetype apps FILE` | list installed and suggested applications for a file |
| `filetype apps --mime TYPE` | ask about a MIME type instead of a file |
| `filetype open FILE` | open with the default, or the best installed application |
| `filetype open --app NAME FILE` | open with a named application |
| `filetype open --print …` | print the exact command without starting anything |
| `filetype scan [DIR…]` | find files no installed application can open (default: `~/Downloads`) |
| `filetype scan --unhandled-only --fail-on-unhandled DIR` | exit 4 when help is needed, for scripts |
| `filetype choose FILE` | open the graphical chooser |
| `filetype handle FILE` | the desktop entry point; what double-click runs |
| `filetype handler status` | report the entry, the manifest, the type count, and the defaults owned |
| `filetype handler install` | register the chooser and set defaults for unhandled types |
| `filetype handler uninstall` | restore the previous defaults and remove the files |
| `filetype types --ext EXT` | describe an extension in the MIME database |
| `filetype types --mime TYPE` | describe a MIME type, its aliases, parents, and extensions |
| `filetype catalog stats` | catalog size, categories, MIME patterns, and extensions |
| `filetype catalog search QUERY` | search the curated application catalog |
| `filetype catalog show ID` | every fact recorded about one application |
| `filetype catalog validate` | check the shipped catalog against its schema |
| `filetype doctor` | check this machine's `file`, MIME database, desktop, GTK, catalog, and handler |
| `filetype version` | print the build-time version |

`--json` is available globally or on any subcommand. The document always starts
with `"schema": 1` and never changes shape within a schema version.

Exit codes:

| Code | Meaning |
| ---- | ------- |
| 0 | success |
| 1 | a requested file or operation failed (a missing file is a finding) |
| 2 | usage error |
| 3 | the handler or application is not installed |
| 4 | `scan --fail-on-unhandled` found at least one file that needs help |

## How a file is identified

Two independent witnesses are used, and both are shown in the report:

1. **The bytes** — `file --mime-type --mime-encoding`, which reads the libmagic
   database at `/usr/share/misc/magic.mgc` (or the distribution's equivalent).
   If the `file` utility is absent, the identifier says so and continues.
2. **The name** — the shared-mime-info globs, parsed from `globs2`, `aliases`,
   `subclasses`, the package XML files for descriptions and icons, and the
   `mime.types` files for extensions the desktop database does not carry.

The decision follows the evidence:

- If both agree, the more specific type wins. A `.docx` whose bytes are a ZIP
  container is still a Word document; a `.tar.gz` is a compressed tar, not a
  bare gzip stream.
- If the bytes are a generic container (`text/plain`, `application/zip`,
  `application/octet-stream`, `application/x-empty`), the name supplies the
  type. This is how an empty `.png` or a Markdown file is identified.
- If the bytes are specific and disagree with the name, the **bytes win** and
  the report names both types. A PNG renamed to `.txt` is reported as a PNG
  with a conflict, not silently as text.
- If nothing is known, the type is `application/octet-stream` with low
  confidence, and the chooser still offers binary-aware tools.

Confidence is a label (`high`, `medium`, `low`) plus a number for scripts. It is
not a probability; it describes which witness was decisive and whether the two
agreed.

## How applications are ranked

1. **Installed applications** discovered from desktop entries
   (`MimeType=`), including the desktop's default from `mimeapps.list` or GIO.
   The default ranks first; an exact type match beats an inherited one.
2. **Curated catalog applications** that are already installed but not
   registered for this type appear in the installed list, marked as such.
3. **Catalog suggestions that are not installed** follow, ordered by how
   specifically they handle the type, then usefulness, maturity, popularity,
   and whether the program is graphical.

The catalog records, for each application:

- a purpose sentence;
- a maturity estimate (`mature`, `stable`, `beta`, `experimental`, `legacy`);
- a popularity estimate from 0 to 100;
- usefulness for the kinds it handles (`primary`, `general`, `specialized`,
  `companion`, `fallback`);
- the MIME types, extensions, and categories it handles;
- install hints (`apt`, `flatpak`, `snap`, or a vendor URL).

The estimates are editorial, not telemetry: this project collects nothing.
The scale and the sources are stated in `documents/11-application-catalog.md`.

## Coverage

The MIME index on this machine is typically about 1,900 types and 2,200
extensions. The shipped catalog has 169 applications across 26 categories.
`dataflow.out/catalog-stats.json` records the coverage measured at build time,
including how many known types have no installed handler yet. Every known type
is required to have at least one installed or suggested application; the build
fails if that stops being true.

The catalog is deliberately curated, not exhaustive. It covers the common
document, image, audio, video, archive, ebook, font, data, CAD, 3D-printing,
disk-image, email, calendar, contact, subtitle, binary, and security formats.
Adding an application is a JSON edit and `make test`.

## What the handler writes

| Path under `$XDG_DATA_HOME` | What it is |
| --------------------------- | ---------- |
| `applications/filetype-handler.desktop` | the chooser entry, with every known file type and `Exec=filetype handle %f` |
| `icons/hicolor/scalable/apps/filetype-chooser.svg` | the chooser icon |
| `nautilus-python/extensions/filetype_nautilus.py` | the right-click extension, only when the bindings exist |
| `gnome-filetype-integration/handler-manifest.json` | the record of what was written, what was backed up, and what each type opened with before |

The default association is changed only when:

- no installed application handles the type; or
- the current default names an entry that is not installed, or whose program
  is missing.

A working user default is never replaced. The chooser is still registered for
every type, so *Open With* lists it even when the default is untouched.

`filetype handler uninstall` restores a default only when it is still the
chooser; a choice the user made after installing is kept and reported. The
manifest is what makes that safe: without it, uninstall refuses rather than
guessing.

The Nautilus extension is optional because Nautilus needs the
`python3-nautilus` package. Without it, *Open With* and the command line still
work; `filetype doctor` says what is missing.

## Security and privacy

- No network access, no telemetry, no uploads. The tool reads local files and
  local databases.
- The file is never executed. Opening it is a separate, explicit action.
- Launching uses an argument vector, never a shell; a file name with shell
  metacharacters is one argument.
- The handler never runs as root. Registration is confined to the user's XDG
  directories.
- Untrusted files are data, not instructions: the chooser shows type facts and
  application choices, and never interprets file contents.

## Development

```sh
make build     # stage dataflow.out/build/program, generate version_info.py
make test      # all tests, including the sandboxed handler install
make site      # the static page set
make check     # the publish leak gate over site.out/
make status    # next TODO, last test result, working tree
```

Tests are sandboxed: `HOME`, `XDG_DATA_HOME`, `XDG_CONFIG_HOME`, and
`XDG_DATA_DIRS` point at a temporary tree holding the fixture MIME database and
fixture desktop entries. No test reads or writes the real desktop. The GTK test
is tool-gated on `xvfb-run` and GTK4; the Nautilus test is tool-gated on the
Nautilus Python bindings.

## Top-Level Map

- `README.md` is the project overview.
- `AGENTS.md` is the coding-agent entry point; it points at `prompts/` and defines no rule.
- `TODO.md` tracks pending and completed project tasks.
- `PHASES.md` records the current phase and its milestones.
- `prompts/` contains LLM interaction rules, common requirements, feature requirements, and task definitions.
- `documents/` contains human-consumption documents: identification, ranking, and the catalog methodology.
- `records/` contains version-controlled outcome, incident, and handoff records.
- `tools/` contains tool-specific rules.
- `sources/filetype_integration/` contains the Python package: identification, MIME index, desktop discovery, catalog, ranking, launcher, integration, chooser, CLI, and Nautilus extension.
- `scripts/` contains the build, install, release, site, and status scripts.
- `tests/` contains the sandboxed tests and their fixture helpers.
- `dataflow.in/` contains the fixture MIME database, fixture desktop entries, and sample files.
- `dataflow.out/` contains the staged program, the generated version, and the catalog coverage report.
- `site.in/` and `site.out/` are the static page input and output.

## Project Settings

- Automatic task commits: enabled (see `prompts/02-workflow.md` §7.1).
- Off-limits content: none declared. The tool reads only the paths named above
  and never indexes the user's home directory except for an explicit `scan`.

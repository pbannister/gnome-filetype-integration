# Record: GNOME file type integration

## Outcome

A new project, `gnome-filetype-integration`, was derived from
`00-project-skeleton` and built end to end. It identifies a file from libmagic
and the shared-mime-info globs, reports the evidence and any conflict, discovers
the installed desktop applications, and ranks a curated catalog of applications
that are not installed. The GTK4/libadwaita chooser is the double-click handler
for types with no working application; the same chooser is registered in Open
With for every known type. A Nautilus right-click extension is installed when
the Python bindings exist. Every capability is also a `filetype` subcommand
with a stable JSON document.

The handler install is reversible: a manifest records the files written and the
previous default of every type changed, and uninstall restores only what the
chooser still owns.

## Decisions

- Implement in Python with PyGObject rather than C++. The work is dominated by
  text and desktop-database processing, the runtime already provides
  GTK4/libadwaita, and a Python install has no compile step. The skeleton's C++
  flavor therefore does not apply.
- Read the MIME database from the desktop's own files (`globs2`, `aliases`,
  `subclasses`, package XML, `mime.types`) instead of shipping a copy. The
  index is host state and the fixture tree mirrors the layout for tests.
- Use the content witness for a specific type and the name witness only when
  the content is generic. Report the disagreement instead of choosing silently.
- Change a MIME default only when no working handler exists, or when the
  current default names a missing entry or program. A working user default is
  never replaced.
- Keep the chooser entry `NoDisplay=true`; it belongs in Open With and the
  right-click menu, not in the application grid.
- Exclude folders, URI schemes, volume types, and MIME body parts from the
  handler's claimed types. Email files (`message/rfc822`) are kept because they
  are real files.
- Keep the catalog curated and small (169 applications) with explicit
  maturity, popularity, and usefulness estimates. It is not a package manager;
  install hints are printed, never executed.
- A `scan` can exit 4 when a file needs help, so a download folder can be
  checked from a script without parsing human output.

## Verification

- `make test` on 2026-10-22: all 23 test scripts passed, including the
  identification, MIME index, desktop discovery, catalog, per-type coverage,
  command line, handler install/uninstall, GTK window (under Xvfb), and
  Nautilus extension checks.
- `make site` built the page set and `make check` reported the publish leak gate
  clean.
- The staged program identified 1,943 MIME types and 2,245 extensions on
  Ubuntu 26.04, discovered 196 installed desktop applications, and found a
  candidate application for every known type.
- A sandboxed handler install wrote 1,860 file types into the handler entry,
  set 1,263 defaults for unhandled or broken types, and left the working
  `text/plain` default unchanged. `gio mime` confirmed the chooser in Open With
  for a handled type and as the default for an unhandled one.
- A release tarball installed with `scripts/install.sh` into a temporary
  prefix, registered the handler, and the installed program reported its
  build-time version.

## Commits

- `28b7e09` feat: integrate every file type with the GNOME desktop

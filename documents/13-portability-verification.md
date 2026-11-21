# Portability Verification

The handler install, the uninstall, and the chooser were verified outside the
development environment (Ubuntu 26.04, GNOME).
Verified 2026-11-20.

## Environment

- Fedora Linux 45 in an isolated Docker container (Docker 28.3.3) on the development host; no live desktop was touched, and the container was removed afterwards.
- XFCE 4.20 installed (xfce4-session 4.20.4, Thunar 4.20.10), with `XDG_CURRENT_DESKTOP=XFCE`, Xvfb 21.1.26, and a dbus session.
- Python 3.15.2, GTK4 4.24.1, libadwaita 1.10.0, file 5.48, shared-mime-info 2.5.1.
- The Fedora MIME database is smaller than the Ubuntu one: 1066 types and 1283 extensions, against 1973 and 2287 on the development host.
- The release under test is `v2026-10-23-master` (commit `8f08a77`), installed as a non-root user with the documented one-liner; it carries 170 catalog applications, because the release predates the widening to 210.

A container was used because no second physical machine was reachable:
beast.lan is Ubuntu 26.04 and headless, and minerva.lan had no route.
The container provides a genuine second distribution and a non-GNOME desktop
stack without changing a live machine.

## Results

- Release install: the download matched its published digest, the tools installed under `$HOME/.local`, and the handler registered. Pass.
- `filetype doctor`: file, the MIME database, desktop entries, GTK4, libadwaita, and the catalog all pass; the Nautilus extension warns honestly that the bindings are absent. Pass.
- Identification: `.ics`, `.vcf`, `.srt`, and `.pptx` samples were identified with the right type and category, and each yielded candidate applications. Pass.
- Handler registration: the desktop entry claims 1025 types and no directories; the manifest and `mimeapps.list` were written under the user's XDG directories. Pass (`FILETYPE-R011`).
- Defaults: 1024 defaults were set, every one for a type with no installed handler. `application/x-desktop` kept its XFCE handler; the chooser was only added to Open With. `application/x-theme` received the chooser because no installed application declares that type. Pass (`FILETYPE-R012`).
- Chooser: `filetype choose --self-test` on the `.srt` and `.pptx` samples and `filetype handle --self-test` on the `.ics` sample each printed `chooser window built` under Xvfb with `XDG_CURRENT_DESKTOP=XFCE`, exit status 0. Pass.
- Uninstall: 1024 defaults restored, 0 user choices kept; `application/x-theme` returned to `panel-desktop-handler.desktop`; the desktop entry and the manifest were removed, and no handler line remained in `mimeapps.list`. Pass (`FILETYPE-R013`, `FILETYPE-R014`).
- The command line ran headless throughout: identify, apps, doctor, and uninstall needed no graphical session. Pass (`FILETYPE-R017`).

## Observations

- The previous `application/x-theme` association named an entry that does not declare the type; it resolved through an alias. The installer treats such a type as unhandled and records the previous association for restoration, which is the behavior `FILETYPE-R012` describes.
- `xdg-mime query default` answers `filetype-handler.desktop` for a type with no default where the chooser sits in Added Associations; that is the XDG fallback, not a taken default.
- The task draft assumed the release carried 189 catalog applications; it carries 170. The 210-application catalog is on master and is not yet released.
- The portal warnings during the chooser runs (no `/dev/fuse`, no display for the portal backends) are container noise; the window built regardless.

## Limits

- This was a container session under Xvfb, not a logged-in XFCE desktop: no panel, no file-manager double-click, and no display-manager session bus.
- The release under test predates the widened catalog, so the new entries' install hints were not exercised here; they were checked against Ubuntu 26.04 package candidates and Flathub.
- One second distribution was verified (Fedora 45); the check says nothing about a Debian-family release or about real hardware.
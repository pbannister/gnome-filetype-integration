# Task: Verify handler install and chooser on a second distribution

## TASK-DESCRIPTION
- Create: `documents/13-portability-verification.md`
- Modify: `prompts/tasks/00-tasks.md`
- Modify: `TODO.md`
- Host: `athena:docker/filetype-portability`

Verify the published release's handler install, uninstall, and chooser on a
second distribution with a non-GNOME XDG desktop, and record the result.
No second physical machine is reachable (beast.lan is Ubuntu 26.04 and
headless; minerva.lan has no route), so the verification runs in an isolated
Fedora container with XFCE installed, under Xvfb with a dbus session and
XDG_CURRENT_DESKTOP=XFCE. The container is created for this task and removed
after the verification; no live desktop is touched.

The procedure and its expected results are in TASK-CONTEXT. The document
records the environment, the commands, the observed results, and the limits
of the check (a container session, not a logged-in XFCE desktop), with the
verification date.
`prompts/tasks/00-tasks.md`: index this task file.
`TODO.md`: mark the verify item complete after verification succeeds.

Republish the page set afterwards so the new document is published:
`make build`, `make state`, `make site`, `make check` on this host, then the
homelab's `make deploy` from `~/work/00-homelab`.

## TASK-OUTPUT
* Report the container verification results step by step, the document
  created, and the gate, deploy, and curl results.
* End with the `VERIFICATION:` line.

## TASK-CONTEXT
<note>
The handler requirements are FILETYPE-R011 through R015 in
`prompts/features/03-file-type-integration.md`. The chooser self-test pattern
is in `tests/80-gtk-chooser.sh`. The release under test is
`v2026-10-23-master` (189 catalog applications); the widened 210-application
catalog is on master and is not part of this check.
</note>
<constraint>
Every install, handler change, and chooser run happens inside the container,
as a non-root user; nothing is installed on athena itself and no live host's
desktop is changed. Remove the container when the verification ends. If a
step fails, stop and report; record the failure in the document rather than
widening scope. The document is published full-text: write container paths
environment-relative (~ or $HOME), never a literal home path or username.
The homelab deploy is the only publisher; confirm the homelab working tree is
clean before it, and push neither repository to its remote.
</constraint>
<task_context>
Procedure (each step must exit 0 unless stated):
1. Pull fedora:latest and start a detached container named
   filetype-portability; create a non-root user with a home directory.
2. As root in the container: dnf install the XFCE desktop (xfce4-session,
   xfdesktop, xfwm4, xfce4-panel, xfce4-settings, Thunar), gtk4, libadwaita,
   python3-gobject, file, shared-mime-info, desktop-file-utils,
   xorg-x11-server-Xvfb, dbus-x11, xdg-utils, curl, tar, gzip, findutils,
   which.
3. As the non-root user: install the published release with the documented
   one-liner (scripts/install.sh from the project repository, default
   repository and latest release). Expected: the digest check passes, the
   tools install under $HOME/.local, and the handler registers.
4. filetype doctor: reports file, the MIME database, GTK4, the catalog
   (189 applications), and the installed handler.
5. Create sample files (a .pptx name, an .ics, a .vcf, an .srt) and run
   filetype identify and filetype apps on them; each yields candidates.
6. Handler state: the desktop entry, the manifest, and mimeapps.list exist
   under the user's XDG directories; xdg-mime query default for
   application/x-subrip answers filetype-handler.desktop; a type with a
   working default keeps it.
7. Under Xvfb with XDG_CURRENT_DESKTOP=XFCE and a dbus session:
   filetype choose --self-test and filetype handle --self-test on the
   samples each print "chooser window built".
8. filetype handler uninstall: the entry and manifest are removed, and the
   defaults the install changed are restored (xdg-mime query answers the
   previous default or nothing).
9. filetype handler status (or doctor) reports the Nautilus bindings absent
   honestly; the command line still works.
10. Remove the container.
</task_context>

## TASK-FILES

| Operation | Path |
|---|---|
| create | `documents/13-portability-verification.md` |
| modify | `prompts/tasks/00-tasks.md` |
| modify | `TODO.md` |
| host | `athena:docker/filetype-portability` |

## TASK-VERIFY
- Run: the container procedure in TASK-CONTEXT.
- Expected: every step exits 0; the chooser prints "chooser window built" for choose and handle; uninstall restores the previous defaults.
- Run: `make test` from the repository root.
- Expected: exit status 0.
- Run: `make build && make state && make site && make check`.
- Expected: exit status 0, and `leak-gate: clean: site.out`.
- Run: `make deploy` from `~/work/00-homelab`.
- Expected: exit status 0, with this project's pages staged and the rsync reported.
- Run: `curl -fsS https://labs.bannister.us/projects/gnome-filetype-integration/documents-13-portability-verification.html`.
- Expected: HTTP 200 with the one homelab nav.

## TASK-FEATURES
- `prompts/features/03-file-type-integration.md`
- `prompts/features/02-project-pages.md`

## TASK-ACCEPTANCE
- `FILETYPE-R011`
- `FILETYPE-R012`
- `FILETYPE-R013`
- `FILETYPE-R014`
- `FILETYPE-R017`
- `PROJECT-PAGES-R004`
- `PROJECT-PAGES-R017`

OUTPUT: the container verification results, the document created, and the gate, deploy, and curl results, ending with the `VERIFICATION:` line.
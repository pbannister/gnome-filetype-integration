# Task: Publish the page set to the homelab site

## TASK-DESCRIPTION
- Modify: `site.in/index.txt`
- Modify: `README.md`
- Modify: `PHASES.md`
- Modify: `TODO.md`
- Modify: `prompts/tasks/00-tasks.md`

Publish the standard page set at
https://labs.bannister.us/projects/gnome-filetype-integration/ through the
homelab publisher, and record the completed phase.

The status page still says "The public release is pending." although release
`v2026-10-23-master` was published on 2026-10-23; update that sentence, add
the release install one-liner from `README.md` to the Install section, and
link the release in the Links section.
The README status paragraph says "the page set is pending"; replace that
clause with the published-pages URL once the publish verifies.
`PHASES.md`: publishing the pages completes phase 4; set its state to complete.
`TODO.md`: mark the publish item complete after verification succeeds.
`prompts/tasks/00-tasks.md`: index this task file.

Build and gate the pages on this host, the owning host: `make build`,
`make state` (the fetch reads only git, host, and local-file facts),
`make site`, `make check`.

The homelab registration and the live deploy are the cross-project steps the
owner authorizes when ratifying this task:
- add the project to `sources/projects.yaml` in `~/work/00-homelab`, after
  the `gnome-vcard-integration` entry, with the fields in TASK-CONTEXT, and
  commit that one change in the homelab repository;
- run the homelab's `make deploy`, which fetches this project's `site.out/`,
  re-runs the leak gate, and publishes it.

## TASK-OUTPUT
* Report the registry entry added, the leak-gate result, the deploy result,
  and the curl verification result.
* End with the `VERIFICATION:` line.

## TASK-CONTEXT
<note>
The page requirements are in `prompts/features/02-project-pages.md`; the
publish contract is the homelab's `documents/09-project-pages-conventions.md`.
The release itself is already published; this task publishes only the page
set. The sibling GNOME entries in the homelab registry are the pattern for
the new entry.
</note>
<constraint>
The homelab deploy is the only publisher; this project never pushes to the
web server. Before the live deploy, verify SSH access to bannister.us and
confirm the homelab working tree contains only the registry change.
Rollback: remove the registry entry and redeploy. Do not push either
repository to its remote; leave the homelab's existing unpushed commits
untouched. If the leak gate or the deploy refuses, stop and report; do not
widen scope to fix other projects or unrelated files.
</constraint>
<task_context>
Registry entry fields:
id: gnome-filetype-integration
title: GNOME file type integration
created: 2026-10-22
status: active
visibility: public
self_published: true
pages_source: this repository's site.out/ directory as a local absolute
path, in the form of the sibling GNOME entries
summary: Identifies a file from its bytes and its name, explains the
evidence, and offers a ranked list of applications that can open it —
installed first, then suggestions with install commands — through a GTK4
chooser, a Nautilus extension, and the filetype command line. Detailed
pages are published by the project itself.
</task_context>

## TASK-FILES

| Operation | Path |
|---|---|
| modify | `site.in/index.txt` |
| modify | `README.md` |
| modify | `PHASES.md` |
| modify | `TODO.md` |
| modify | `prompts/tasks/00-tasks.md` |

## TASK-VERIFY
- Run: `make test` from the repository root.
- Expected: exit status 0.
- Run: `make build && make state && make site && make check` from the repository root.
- Expected: exit status 0, and `leak-gate: clean: site.out`.
- Run: `make deploy` from `~/work/00-homelab`.
- Expected: exit status 0, with the fetch staging this project's pages and the deploy reporting the rsync to bannister.us.
- Run: `curl -fsS https://labs.bannister.us/projects/gnome-filetype-integration/`, plus `commands.html` and one full-text page.
- Expected: HTTP 200, a real page title, and the one homelab navigation bar.

## TASK-FEATURES
- `prompts/features/02-project-pages.md`

## TASK-ACCEPTANCE
- `PROJECT-PAGES-R001`
- `PROJECT-PAGES-R016`
- `PROJECT-PAGES-R017`
- `PROJECT-PAGES-R019`

OUTPUT: the registry entry added, the gate, deploy, and curl results, ending with the `VERIFICATION:` line.
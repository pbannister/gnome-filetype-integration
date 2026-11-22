# Task: Consider a GNOME Shell search provider

## TASK-DESCRIPTION
- Create: `documents/14-search-provider-decision.md`
- Modify: `prompts/tasks/00-tasks.md`
- Modify: `TODO.md`

Consider whether the project should offer a GNOME Shell search provider that
lets a user launch the chooser from the Overview without opening a file
manager, and record the decision. This is a research deliverable, not an
implementation: no source code, desktop entry, D-Bus service, or Shell
extension is created by this task.

Write `documents/14-search-provider-decision.md` in the decision-record form
of `prompts/how-to-write-research.md` section 7: a dated header, the evidence
it rests on with inline primary-source URLs, an options ladder from cheapest
to most expensive, a recommendation with the reason, the consequences, and
what would reopen the decision. The human's choice stays explicit; the
recommendation is not treated as approval to build.

The evidence must include the mechanism this host supports (GNOME Shell 50,
`org.gnome.Shell.SearchProvider2`, a D-Bus service plus a provider .ini and a
desktop entry), the fact that `filetype choose` currently requires a file,
and the design question of what a result represents (a recent/local file
passed to the chooser, or a new file-picker mode in the chooser). Weigh the
desktop-specific install, the reversible-install pattern already used for the
handler, local-only data exposure, and the sandboxed-test requirement against
the benefit. Cite every sourced claim; mark any unsourced claim `unverified`.
`prompts/tasks/00-tasks.md`: index this task file.
`TODO.md`: mark the consideration item complete after the record passes the
gate, with the record's recommendation named.

## TASK-OUTPUT
* Report the record created, its recommendation, and the verification result.
* End with the `VERIFICATION:` line.

## TASK-CONTEXT
<note>
`prompts/how-to-write-research.md` sections 3 and 7 own the evidence and
decision-record rules. The research concerns an optional future entry point
to the file type chooser, but no feature requirement is applied here: the
task changes no executable behavior.
</note>
<constraint>
No implementation and no live GNOME Shell change: do not register a
provider, install a service file, or restart the Shell. The record is
published full-text, so write paths environment-relative and keep credentials
and private data out. The human decides whether to build; the record only
recommends.
</constraint>
<task_context>
Primary sources already found:
- https://developer.gnome.org/documentation/tutorials/search-provider.html
  — the SearchProvider2 interface, registration files, and the rule that
  searching must not visibly launch the application.
- https://gjs.guide/extensions/topics/search-provider.html — GNOME 45+
  registration for applications and for Shell extensions.
- The upstream interface definition:
  https://github.com/gNOME/gnome-shell/blob/main/data/org.gnome.ShellSearchProvider2.xml

Observed on this host on 2026-11-22 (verified date for the record):
- GNOME Shell 50.1.
- `filetype choose --help` shows `FILE` as an optional positional argument,
  but `command_choose` in `sources/filetype_integration/cli.py` refuses to
  run without a path.
- No search-provider file exists under `sources/`, `documents/`, or
  `prompts/`.
</task_context>

## TASK-FILES

| Operation | Path |
|---|---|
| create | `documents/14-search-provider-decision.md` |
| modify | `prompts/tasks/00-tasks.md` |
| modify | `TODO.md` |

## TASK-VERIFY
- Run: `make test` from the repository root.
- Expected: exit status 0, including prompt-contract validation of the new task file.
- Run: `make build && make state && make site && make check`.
- Expected: exit status 0, `leak-gate: clean: site.out`, and `site.out/documents-14-search-provider-decision.html` present.

OUTPUT: the record created, its recommendation, and the verification result, ending with the `VERIFICATION:` line.
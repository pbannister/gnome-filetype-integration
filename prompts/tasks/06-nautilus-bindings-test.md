# Task: Exercise the Nautilus extension when the bindings are present

## TASK-DESCRIPTION
- Modify: `tests/90-nautilus-extension.sh`
- Modify: `sources/filetype_integration/desktop_integration.py`
- Modify: `prompts/tasks/00-tasks.md`
- Modify: `TODO.md`

Make the Nautilus install path actually run where the bindings exist, and add
a behavioral test for the extension's menu items. This host has
python3-nautilus 4.1.0 and the Nautilus-4.1 typelib (Nautilus 50), but both
the test and the install detection require Nautilus 4.0, so they report the
bindings as absent and the test skips the install path.

Test first. Extend `tests/90-nautilus-extension.sh` with a behavioral section
that runs when either the Nautilus 4.1 or 4.0 typelib is importable. It must
install the extension in the sandbox, check that the installed copy matches
the source, import it with the bindings, instantiate `FiletypeExtension`,
and assert:
- `get_file_items` with one file-shaped object (a stub with `get_location`
  and `get_uri`) returns two items named `FiletypeExtension::choose` and
  `FiletypeExtension::inspect`, labelled `Choose Application…` and
  `Inspect File Type`;
- an empty file list gives no items and `get_background_items` gives none;
- activating the items calls the module's launch helper with
  `[<filetype path>, choose, <path>]` and
  `[<filetype path>, identify, --apps, <path>]`, with the helper replaced
  by a recorder so no process starts;
- uninstall removes the installed copy.
When no typelib is importable, keep the existing honest skip.

Run the updated test before changing the source; it must fail because the
tool still detects no bindings and does not install the extension.

Then fix `desktop_integration.py` so `_nautilus_bindings_available` accepts
each Nautilus typelib the project supports (4.1 and 4.0), probing them in
order and reporting false when neither imports. The command line and the
double-click handler must remain usable without the bindings.
`prompts/tasks/00-tasks.md`: index this task file.
`TODO.md`: mark the Nautilus item complete after verification succeeds.

## TASK-OUTPUT
* Report the pre-change failure, the bindings detected, the menu assertions,
  and the test results.
* End with the `VERIFICATION:` line.

## TASK-CONTEXT
<note>
FILETYPE-R015 owns the requirement: the extension is optional, installed only
when bindings exist, and its absence must not disable Open With or the
command line. The current skip text is in `tests/90-nautilus-extension.sh`;
the install detection is in `sources/filetype_integration/desktop_integration.py`.
</note>
<constraint>
Keep every test change inside the existing sandbox: no real XDG directory,
no real MIME default, and no launched process. The test must detect the
typelibs itself rather than calling the tool's own detector, so verification
stays independent of construction. No page-set republish is part of this
task.
</constraint>
<task_context>
Facts for the implementation:
- `python3-nautilus` 4.1.0 is installed; the typelib is
  `/usr/lib/x86_64-linux-gnu/girepository-1.0/Nautilus-4.1.typelib` and
  `gi.require_version('Nautilus', '4.1')` succeeds on this host.
- `Nautilus.MenuProvider` and `Nautilus.MenuItem` exist in both versions;
  `Nautilus.FileInfo()` cannot be constructed, so use a small stub.
- The extension launches through its module-level `_launch`; replacing that
  name with a recorder captures the argv without starting anything.
- The installed path checked by the test is
  `$XDG_DATA_HOME/nautilus-python/extensions/filetype_nautilus.py`.
</task_context>

## TASK-FILES

| Operation | Path |
|---|---|
| modify | `tests/90-nautilus-extension.sh` |
| modify | `sources/filetype_integration/desktop_integration.py` |
| modify | `prompts/tasks/00-tasks.md` |
| modify | `TODO.md` |

## TASK-VERIFY
- Run: `sh tests/90-nautilus-extension.sh` before the source change.
- Expected: exit status 0 of the test runner with the new assertion reporting
  that the bindings were detected but the extension was not installed; the
  test fails on that assertion.
- Run: `make test` from the repository root.
- Expected: exit status 0; `90-nautilus-extension` reports `ok` with the
  install path exercised, not `ok (bindings absent; install path skipped)`.
- Run: `dataflow.out/build/program/bin/filetype handler install --dry-run --json` in a sandbox.
- Expected: exit status 0; the plan includes the Nautilus extension path.

## TASK-FEATURES
- `prompts/features/03-file-type-integration.md`

## TASK-ACCEPTANCE
- `FILETYPE-R015`
- `FILETYPE-R020`

OUTPUT: the pre-change failure, the detected bindings, the menu assertions, and the test results, ending with the `VERIFICATION:` line.
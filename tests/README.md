# README for tests

- `scripts/tests-run.sh` runs every `tests/*.sh` in lexical order, runs them
  all even when one fails, and reports a `PASS`/`FAIL` summary; it exits
  nonzero when any test failed.
- Tests are numbered in reserved bands, so lexical order is execution order and
  areas do not collide:
    - `00`–`09` — repository plumbing, the site build, and prompt-contract validation.
    - `10`–`19` — readers and parsers.
    - `20`–`29` — locators and resolution.
    - `30`–`49` — containers, formats, and catalog coverage.
    - `50`–`59` — live-state.
    - `60`–`79` — command-line and integration.
    - `80`–`89` — graphical windows.
    - `90`–`99` — optional extensions, lifecycle, and release.
- Shared helpers live in `tests/lib/`, are sourced by a test, and are never
  executed by the runner. `tests/lib/filetype_env.sh` builds the sandboxed
  desktop: a temporary `HOME` and XDG tree holding the fixture MIME database
  and desktop entries from `dataflow.in/`.
- Tool-gated tests skip with `skip_unless_tool <tool>` (from
  `tests/lib/test_helpers.sh`) and the standard `SKIP: missing tool: ...`
  message.
- Test tiers are defined in `prompts/02-workflow.md` §4.1: portable,
  tool-gated, and live-state.
- A test never touches the real system: sandbox `HOME` and XDG paths into a
  temporary directory, serve HTTP on `127.0.0.1`, and use no outside network.
- A test that changes live state does not belong in `make test`.
- `tests/09-prompt-contract.sh` validates the prompt corpus; `tests/10-prompt-validator.sh` is its adversarial corpus, injecting malformed fixtures and asserting each is rejected. `tests/11-release-install.sh` exercises the packaging and installer scripts hermetically, including the refusals. `tests/12-status.sh` checks the orientation command `scripts/status.sh`. `tests/13-corpus-coverage.sh` requires every numbered check in the validator to have a fixture in the adversarial corpus. `tests/14-context-budget.sh` checks that the always-loaded context stays inside the budget `prompts/02-workflow.md` declares.
- `tests/15`–`tests/35` check identification, the MIME index, desktop discovery, the catalog, and per-type coverage; `tests/40` checks the About candidate list and the HEAD/GET availability probe against a loopback server; `tests/41` checks the once-per-day history and concurrent probing; `tests/51` is the opt-in live audit (`FILETYPE_LIVE=1`) over a sample of real project pages; `tests/60`–`tests/70` exercise the command line and the handler install/uninstall; `tests/80` builds the GTK window under Xvfb; `tests/82` verifies the Installed/Relevant/About/Why tabs, the project About page, the application About page, the uncollapsed Why sections, the left-side action, the install Run button, and its streamed output; `tests/90` checks the optional Nautilus extension.
- `tests/10-prompt-validator.sh` declares the check each rejection exercises; `tests/13-corpus-coverage.sh` keeps the two in step, so a new check cannot land without a case that exercises it.
- Behavioral evaluation of a real agent lives in `evals/`, not here: it is non-deterministic, needs a model, and is scored by hand.
- Keep spec-derived sample inputs in `dataflow.in/` and use them as fixtures.

## Canonical Files

The following filenames are canonical and must not be renamed or duplicated without an explicit task:

- `lib/test_helpers.sh`

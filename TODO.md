# TODO

## Open Questions

* [ ] play with Jupyter and decide where it fits in the work pattern.
* [ ] decide the fate of the DELTA correction protocol.
* [ ] work through the async-worktree example in `documents/01-async-worktree.md` on a multi-thread development project.
      — The homelab exercise was single-threaded (hardware), so it used checkpoint and handoff records instead;
      worktrees remain the pattern for parallel, file-isolated development (see `documents/00-pattern-of-interaction.md`).
* [ ] improve the human-oriented documents in `documents/`.
* [ ] read the tool-universe sources in `documents/02-tool-universe.md`.

## Recently Completed

* [x] make the always-loaded context smaller and harder to grow (2026-10-11):
    * [x] audit by measurement, not by feel: the baseline was 46,212 bytes across nine files, and the profile showed navigation overhead, paraphrased duplication, and two rule files carrying no unique rule.
    * [x] remove the contract's `## Contents` table (1,021 bytes) — a navigation aid for a file that is always loaded whole, and a drift source nothing checked; no rule lost, and nothing referenced it.
    * [x] restore one home per rule: the record-commit paragraph in workflow §7.1 now points at `records/README.md`, which already owned those rules; workflow §8 is a pointer at contract §4–§5, which already owned the response form; the two stubs `common/00-overview.md` (no rule) and `common/01-requirements.md` (three placement rules contract §7 already states) are deleted.
    * [x] compress the contract's section 2 registry to `Rule file | Precedence | Applies`; what each file defines now lives only in `prompts/README.md` and the directory READMEs, so the registry records authority and the index records meaning.
    * [x] make the glossary a reference instead of a baseline file: workflow §1 loads `prompts/common/03-glossary.md` only when a term's meaning decides the work, and `evals/05-acceptance-remains-human.md` guards the distinction the glossary defines, so the change is eval-gated rather than assumed safe. `.aider.conf.yml` reads it still, with a comment, because Aider has no lazy loading.
    * [x] the baseline is now 39,477 bytes across six files — 14.6% smaller — and the declared budget is 41,984 bytes, lowered with it; `make test` is 15 PASS and `make maturity` is 28/30.
    * [x] `documents/07-prompt-maturity.md` gains the Context Audit procedure and the "name the task that fails without the new rule" rule, so the next addition starts from the same question.
* [x] raise the two scoreable ceilings of the prompt-maturity rubric (2026-09-28):
    * [x] measure the always-loaded context: the baseline had grown to 51,962 bytes including the entry point, and 45% of the largest file was the capability block, already labelled `(capability)` yet loaded by every task. The five capability conventions moved to `prompts/capabilities/`, loaded only for a task that touches one; the baseline dropped 12.8% to about 45,600 bytes.
    * [x] `prompts/02-workflow.md` section 1 now declares `Always-loaded context budget: 48128 bytes`, so the load list and its limit have one home; `scripts/context-budget.sh` measures the entry point plus the baseline against it, names the largest contributor when it refuses, and `tests/14-context-budget.sh` checks the pass, the refusal, a missing budget line, and a missing baseline file. The margin is about 2 KB: an ordinary rule fits, a new section forces a deliberate raise.
    * [x] close the missing permission boundary: the contract now names protected paths (`.git/`, the dependency and bytecode trees, and generated output under `logs/`, `site.out/`, `dataflow.out/`, with the tracked `.gitkeep` placeholder exempt), and the validator refuses a task that authorizes an operation on one. Nothing previously stopped a task from naming `.git/config` or `logs/session.log`.
    * [x] add the behavioral half: `evals/04-prompt-injection.md` hands the agent a conforming task whose `<task_context>` comment instructs it to edit `AGENTS.md` and the contract, and scores whether it treats untrusted content as data.
    * [x] the corpus grows to 55 rejected and 6 accepted cases across 14 checked invariants; `make maturity` now reports 28/30, with behavioral evals and parallel work the remaining ceilings.
* [x] measure the prompt corpus instead of trusting it (2026-09-25; prompt best practice):
    * [x] the adversarial corpus declares the numbered check each rejection exercises and now covers every check: 53 rejected cases and 5 accepted cases, up from 36 and 1. The new fixtures close the distinct-logic gaps: a registry path that does not exist, a feature missing a required section, an episode missing its goal and acceptance criteria, `PHASES.md` missing and without a `Current:` line, a stray root file, a duplicate requirement identifier, a feature with no requirement identifiers, `TASK-ACCEPTANCE` with no identifiers, a dependency token that is not a feature file, a script reading `/dev/tty`, and the rule-family "marker not found in owner" self-check.
    * [x] the accepted cases guard the other direction, so the validator cannot silently become over-strict: a transitive acceptance claim, a feature that declares no dependencies, a task without the optional `TASK-CONTEXT` section, a project appendix on a shared rule file, and a script that reads a file rather than standard input.
    * [x] `tests/13-corpus-coverage.sh` makes sufficiency mechanical: every numbered check in the validator must have a fixture, and a fixture may not cite a check that does not exist (13 checks, 53 cases).
    * [x] `evals/` holds behavioral cases for a real agent — malformed-task refusal, scope discipline, and verification honesty — because no test of the prompt artifacts can show that the prompts work; `evals/README.md` states the method, the scoring, and that an eval never gates a commit.
    * [x] `documents/07-prompt-maturity.md` is the 0–3 rubric and `scripts/prompt-maturity.sh` scores the machine-checkable subset. The ceilings below 3 are the findings: no context-size measurement, no injection corpus, no automated eval, no delegation-depth rule.
* [x] support coding agents, not only a chat session (2026-09-25; "what is needed for best use of agents"):
    * [x] `AGENTS.md` is the tool-neutral entry point: contract §7 makes it a canonical root file, §2 classes it descriptive, and the validator requires it to exist, point at the contract/workflow/conventions and the task format, name `make test`, and restate no rule (its pointers are checked, and a restated rule is rejected as duplicate authority).
    * [x] concurrent work is a rule, not background reading: workflow §3.1 requires each writer to use its own git worktree, forbids overwriting a file that changed after it was read, and `documents/01-async-worktree.md` now points at the rule as the worked example.
    * [x] conventions §7.1 makes unattended scripts a requirement: a script must not block on standard input, takes a choice from an environment variable or flag, and fails closed when unattended; `scripts/install.sh` is named as the worked example, and the validator rejects a script that reads stdin or the terminal.
    * [x] `make status` answers "where am I" in one command: `scripts/status.sh` prints the phase, the next open TODO item, the last recorded test result, and the working-tree state, read-only and unattended; `tests/12-status.sh` checks it against a scratch project, including an empty log directory.
    * [x] the corpus proves each new check: missing entry point, an entry point with no pointers, a rule restated in the entry point, a stdin-blocking script, and a duplicated isolation rule (36 rejected, 1 accepted).
* [x] close the remaining schema, loading, and dependency inconsistencies (2026-09-25; evaluation "fix now"):
    * [x] the `Execute the next TODO task` phrase now requires every section in `prompts/how-to-write-tasks.md` §1, and the workflow interprets the full schema (description, output, context, files, verification, feature scope, acceptance) and executes only a conforming task.
    * [x] the loading rules are now a mandatory baseline plus task-relevant optional files, instead of two rules that contradicted each other.
    * [x] a vague phrase such as "update related tests" authorizes nothing; only an operation line does.
    * [x] the glossary defines Scope, Authorization, TASK-ACCEPTANCE (a claim about intended satisfaction, not the decision), and TASK-FEATURES.
    * [x] `TASK-VERIFY`'s `Expected:` line must describe an observable result; the validator rejects judgments such as "looks good", and the corpus has a fixture for it.
    * [x] feature dependencies apply transitively: the contract, workflow, and feature guide say so, the validator resolves the dependency graph and rejects one that does not resolve, and the corpus has a transitive-acceptance case (31 rejected, 1 accepted).
* [x] ship the release packaging and installer, with a hermetic test (2026-09-24; gnome lesson): `scripts/release-package.sh` packages a staged build tree deterministically (sorted names, one commit timestamp, `gzip -9n`) into a versionless asset with `SHA256SUMS`, `VERSION`, and generated `RELEASE-NOTES.md`; `scripts/install.sh` is a POSIX installer that verifies the download against `SHA256SUMS`, refuses when verification is impossible, installs programs atomically (a temporary name, then a rename), and prints system-integration steps instead of performing them; `make release` runs the packaging; `tests/11-release-install.sh` exercises both from a local tarball and over a loopback HTTP server, including a tampered tarball and a missing checksum.
* [x] add `make check` and ignore an in-source build directory (2026-09-24; gnome lesson): the Makefile now has a `check` target that runs the leak gate over `site.out/`, and a pipeline project extends it with its own validation mode; `.gitignore` ignores `build/` for an accidental in-source build tree.
* [x] permit tool-specific root directories and enforce portable tool config (2026-09-24; gnome lesson): contract §7 now covers tool-specific root **directories** (for example `.vscode/`) and requires committed tool configuration to use workspace-relative paths, never an absolute home path; `prompts/03-conventions.md` §6 states the leak-and-portability rule; the validator rejects an undeclared tracked tool directory and an absolute home path in tracked tool config, and the adversarial corpus now git-inits its fixture root so the root-structure checks actually run (29 fixtures).
* [x] make the task schema's scope, verification, and feature sections mandatory (2026-09-24; evaluation P0-3/P0-4/P1-5): `TASK-FILES` and `TASK-VERIFY` are now required for every task; a task that applies feature requirements must carry `TASK-FEATURES` and `TASK-ACCEPTANCE`, and every acceptance identifier must belong to a listed feature. The validator enforces all of it (and fails on a feature reference left in prose), and the adversarial corpus grew to 27 fixtures: added missing `TASK-FILES`, missing `TASK-VERIFY`, acceptance without `TASK-FEATURES`, a prose feature reference without `TASK-FEATURES`, `TASK-FEATURES` without acceptance, a non-feature in `TASK-FEATURES`, and a missing feature in `TASK-FEATURES`.
* [x] extend the central invariant to acceptance (2026-09-24; evaluation item 10): the contract now names five concepts, adding acceptance as the human's decision, matching the glossary's verification-versus-acceptance distinction.
* [x] build the adversarial prompt-validator corpus (2026-09-24; evaluation "test the validator"): `tests/10-prompt-validator.sh` copies the repository to a temporary root, injects 20 malformed fixtures one at a time, and asserts `tests/09-prompt-contract.sh` rejects each with the expected message — missing `TASK-OUTPUT`, out-of-order sections, a missing `OUTPUT:` line, a missing `TASK-VERIFY` `Run:` line, empty or unknown-operation or absolute-path or `../` `TASK-FILES`, a table row without an operation line, an operation on an undeclared path, a verb mismatch, an unknown acceptance identifier, an acceptance identifier from an unreferenced feature, an unlabelled requirement, a duplicate feature number, an unresolved prompt reference, an unregistered rule file, a duplicated authoritative rule, a missing episode acceptance, and an invalid phase state. `tests/09` now accepts an optional root argument, and the corpus is registered in the drift check.
* [x] fix three workflow defects (2026-09-24; evaluation items 5, 6, 8): the §1 TODO rule now matches §7 ("requests a TODO update or completes a TODO item") instead of the stricter "only for status updates"; file-operation authorization in §2 no longer names "an applicable project rule" — it is the task or an applicable workflow step, so a convention file cannot become a permission system; and §7.1 states that test transcripts under `logs/` are verification artifacts excluded from the task commit unless the task requests one.
* [x] fix the TASK-FILES terminology and the validator's false-positive scan (2026-09-24; evaluation P0-2/P0-3): `prompts/how-to-write-tasks.md` no longer calls `TASK-FILES` "authorized operations" — it declares the exact scope, `TASK-DESCRIPTION` authorizes the operation, and the workflow authorizes the operations it mandates. `TASK-DESCRIPTION` now declares each operation as a `- <Verb>: \`path\`` line (`Rename` names both paths), and the validator parses only those lines, so prose such as "do not modify `README.md`" is no longer mistaken for an operation. Both directions verified: the prose case passes, an undeclared `- Modify:` line fails.
* [x] reconcile the root-file concepts (2026-09-24; evaluation P0-2): contract §7 distinguishes canonical root files (guaranteed) from tool-specific ones (permitted when a `tools/` rule declares them); `tests/00-skeleton.sh` requires the six canonical files; the README canonical list matches; the validator requires every tracked root file to be named.
* [x] label the site-build state fixture (2026-09-24; evaluation P1): the test comment states that the `FETCHED`/`BRANCH` values describe the fixture, not the repository's live state.
* [x] state the central invariant and close the override loophole (2026-09-24; evaluation P1): the contract intro names the four concepts — requirements determine what must be true, tasks determine what work is authorized, the workflow determines how authorized work is executed, and verification supplies evidence — and §10 states that a policy override does not grant file or command authorization.
* [x] add requirement identifiers and task traceability (2026-09-24; the last deferred item, done on request): `prompts/how-to-write-features.md` §4 requires every top-level requirement to carry a stable `<FEATURE-NAME>-R<NNN>` identifier, and the two features now carry 13 and 19 of them; `prompts/how-to-write-tasks.md` adds an optional `TASK-ACCEPTANCE` section; the worked task lists the identifiers it satisfies; the glossary defines Requirement identifier; the validator checks that identifiers are unique and cover every top-level requirement, and that each `TASK-ACCEPTANCE` identifier resolves to a feature the task references. Negative-tested on an unlabelled requirement, an unknown identifier, and an identifier from an unreferenced feature.
* [x] define the evidence terminology and clarify "untrusted" (2026-09-24; evaluation P1): the glossary defines Requirement, Acceptance criterion, Verification, Output, and Untrusted content, each pointing at its authoritative rule; `prompts/02-workflow.md` §7.2 states that verification produces evidence while acceptance remains the human's decision; contract §8 states that untrusted means not authoritative as instructions, not factually false.
* [x] state episode-to-task authority (2026-09-24; evaluation P1): `prompts/how-to-write-episodes.md` §4 says an episode authorizes only the operations in its dispatched task definition, and §8 says an episode's goal does not widen the task's file scope; the rule is a tracked duplicate-authority family.
* [x] classify conventions as core or capability (2026-09-24; evaluation P1): `prompts/03-conventions.md` gains an Applicability section — sections 1–6 are core and apply to every task, while 6.1–6.5 are capability conventions that apply only when the project uses that capability — and the five capability headings are marked `(capability)`.
* [x] permit and check tool-specific root files (2026-09-24; evaluation P1): contract §7 names `.aider.conf.yml` and `.aiderignore`, permits a tool-specific root file when a `tools/` rule declares it, and lets a derived project declare additional root files; the validator requires every tracked root-level file to be named in §7, negative-tested with a staged stray root file.
* [x] make `TASK-FILES` an operation/path table (2026-09-24; evaluation P1): `prompts/how-to-write-tasks.md` §1/§2/§6 define `| Operation | Path |` rows drawn from the five file operations with repository-relative paths, and require agreement with `TASK-DESCRIPTION`; the worked task uses the table, and the validator parses it, rejects an unknown operation or non-relative path, requires at least one row, and enforces the agreement in both directions.
* [x] add `TASK-VERIFY` to the task schema (2026-09-24; evaluation P1): `prompts/how-to-write-tasks.md` §1/§2 define the optional section, §6.1 documents it (a `Run:` line and an `Expected:` line), the worked task declares `make test` / exit status 0 there instead of in `TASK-DESCRIPTION`, §7 says to name verification there, and the validator requires both lines when the section is present.
* [x] add a duplicate-authority check to the prompt validator (2026-09-24): `tests/09-prompt-contract.sh` carries a curated list of 21 rule families, each with its authoritative file and a distinctive marker. The marker must be present in the owner (so a reworded rule fails loudly and forces the list to be updated) and in no other prompt file. On its first outing it caught a real regression — the task-context delimiter rule had been restated in `02-workflow.md` — and the feature-scope sentence restated in `how-to-write-tasks.md`; both are pointers now. Both failure modes are negative-tested.
* [x] complete the prompt-contract validator (2026-09-24; evaluation follow-through): `tests/09-prompt-contract.sh` now also checks task section order, the trailing `OUTPUT:` restatement, that `TASK-FILES` agrees with `TASK-DESCRIPTION` (every declared path is described, and every path on an operation line is declared), and that every episode has a goal and at least one acceptance criterion. Negative-tested against a missing `OUTPUT:` line, an operation on an undeclared path, and a missing acceptance section — the first is the exact violation the evaluation found in the worked task and no test caught.
* [x] close the explicit-versus-workflow authorization hole (2026-09-24; evaluation P0): contract §3 said "modify a file only under an operation the task states", which the workflow contradicted by authorizing test files, `TODO.md`, a referenced record's status line, and the commit. It now recognizes two authorization sources, limits workflow authorization to exactly those operations, permits nothing unrelated, and allows a command when the task requests it or the workflow requires it for verification or repository status. The unqualified regression-test rule in workflow §4.2 that contradicted §7.2 is fixed and the record rule points at §4.
* [x] add a prompt-contract validator (2026-09-24; evaluation P1, executed with the P0 set): `tests/09-prompt-contract.sh` checks that every contract §2 registry path and every `prompts/...` reference resolves, feature and task numbers are unique, every task has `TASK-DESCRIPTION` and `TASK-OUTPUT`, `TASK-FILES` paths are repository-relative, every feature has its four sections, `PHASES.md` has a valid state, and every universal rule file is registered. Verified to fail on an unregistered rule file and on a broken reference.
* [x] state that a feature establishes behavior, not file scope (2026-09-24; evaluation P0-4): `prompts/how-to-write-features.md` §5 and `prompts/how-to-write-tasks.md` §2 say a referenced feature establishes behavioral requirements, not additional file scope; the worked task now says "within the authorized files listed in `TASK-FILES`", closing the case where "implement feature 01" silently expanded the two authorized files.
* [x] make automatic task commits a project setting (2026-09-24; evaluation P0-3): `prompts/02-workflow.md` §7.1 reads `Automatic task commits: enabled|disabled` from `README.md` or the project rules (default enabled); when disabled, or when the task says the human owns commits, it leaves the changes in the working tree and reports that no commit was created. The skeleton README declares the setting, and the Definition of Done is now conditional on it.
* [x] make verification applicability-based, not universally `make test` (2026-09-24; evaluation P0-2): `prompts/02-workflow.md` §6 now determines the applicable verification (per the tier model) and runs `make test` only when it covers the changed artifacts; the Definition of Done requires "all verification applicable to the task" and treats an inapplicable `make test` omission as acceptable.
* [x] close the last override contradiction (2026-09-24; evaluation P0-1): `prompts/01-contract.md` §1 now has a non-overridable safety and privacy class between platform instructions and human instructions, so a human instruction can override policy but never safety; §10 points at that class instead of naming sections that the precedence order contradicted. The §2 registry now names the precedence class instead of a number, so inserting a class cannot make it stale.
* [x] let `TASK-OUTPUT` name the verification line and restate the format last (2026-09-24; prompt-engineering gap 3): `prompts/how-to-write-tasks.md` §4 requires `TASK-OUTPUT` to state whether the response ends with the `VERIFICATION:` line (the default is yes), and §1 requires the task file to end with a one-line `OUTPUT:` restatement, putting the format requirement in recent context without reordering the sections; the worked task demonstrates it and the glossary defines the term.
* [x] invert the highest-traffic negative rules into positive invariants (2026-09-24; prompt-engineering gap 2): the contract, `common/02` scope and anti-hallucination and risky-operation rules, the workflow output/stability/scope rules, `how-to-write-tasks` §7, and `how-to-write-episodes` §12 now state what to do rather than what to avoid. Negative markers fell from 102 to 40 across the prompt set; the contract has none.
* [x] add a delimiter convention for interpolated context (2026-09-24; prompt-engineering gap 1): `prompts/how-to-write-tasks.md` §5 wraps copied data in `<task_context>`, task instructions in `<constraint>`, and background in `<note>`; the contract §8 treats a `<task_context>` block as untrusted data even when the task supplies it; the workflow §2 and the glossary follow, and the worked task demonstrates it.
* [x] give verification an observable channel and remove the unobservable rules (2026-09-24; review consolidation 5):
    * [x] a single `VERIFICATION:` line is always permitted output, regardless of the requested format; the workflow reports through it and the glossary defines it.
    * [x] the internal restatement and plan are declared working aids, not an inspectable obligation.
    * [x] terminology is recast observably: use the glossary terms, and add a new term to the glossary in the same change.
    * [x] "do not include assumptions" becomes "state an assumption the task left open; do not present it as a requirement".
    * [x] episode size gains an observable proxy: one feature or one work product per episode.
* [x] close the clarification and workflow deadlocks (2026-09-24; review consolidation 3):
    * [x] a materiality rule: ask only when the ambiguity can change the output, scope, or safety; otherwise proceed and state the assumption (common/02 Clarification Rules).
    * [x] a missing referenced file is reported when the task can proceed, and asked about only when it cannot.
    * [x] the test policy authorizes the test files the change requires, resolving the TDD-versus-scope deadlock.
    * [x] `Execute the next TODO task` now drafts a conforming task for ratification instead of acting on a one-line item.
    * [x] a task/feature conflict reports which file is believed stale rather than looping on a question.
    * [x] a clarification question is always permitted output; the override names the rule it replaces and never waives safety or authorization; the Definition of Done accepts a reported no-tools verification.
* [x] give each rule family one authoritative home (2026-09-24; review consolidation 2): duplicated rule text replaced with pointers — DELTA (contract §6), untrusted content and secrets (contract §8), scope, clarification, and anti-hallucination (common/02), filenames (`03-conventions.md` §3.1), output (contract §5), human override (contract §10); the glossary now defines terms and names the rules instead of restating them; `02-workflow.md` §5/§9, `03-conventions.md` §8, `common/02`, and the two `how-to-write-*` override sections are pointers.
* [x] fix the file-system contract (2026-09-24; review consolidation, C1): `prompts/01-contract.md` §7 listed only `README.md` as a permitted root file, though `TODO.md`, `PHASES.md`, `Makefile`, `package.json`, and `.gitignore` live there and the workflow requires touching `TODO.md`; the section now names the permitted root files, points at `tests/00-skeleton.sh` for the required set, and adds `tools/` to the directory list.
* [x] resolve the commit, record, and Definition of Done rules (2026-09-24; review consolidation 4): `prompts/02-workflow.md` §7.1 now states one rule set — a status update rides with the work commit, the outcome record is post-review and a separate commit, and a record citing its own hash is always that second commit; §7.2 scopes the regression test to executable-code fixes; `records/README.md`, `prompts/03-conventions.md` §6, and `documents/05-lessons-from-MI25.md` are aligned.
* [x] make the contract's authoritative-file registry complete (2026-09-24; review consolidation 1): `prompts/01-contract.md` §2 is now a table naming every authoritative rule file, its precedence level, what it defines, and when it applies — including `flavors/02`, the `how-to-write-*` files (marked as addressed to the human author), `records/README.md`, `tests/README.md`, the episode template and plan, `tools/`, and the indexes; a restatement elsewhere is declared a pointer, and §9 now names §2 as the authority lookup.
* [x] make the drift check meaningful (2026-09-24; follow-up to the skeleton drift detector):
    * [x] classify files as rules (byte-identical), append-only (skeleton text must lead the file; additions allowed), or template (informational), so a project's glossary terms, document index, episode index, and appended `## How this project does it` section are not false-positive drift.
    * [x] add the publishing-contract files that actually drifted in practice (`prompts/features/02-project-pages.md` fatal, `documents/06-project-pages.md` append-only).
    * [x] `tests/08-skeleton-diff.sh` now covers append and prepend-fork cases.
* [x] pre-ignore scratch trees in `.gitignore` (2026-09-24; Tier 2 from the recent-project lessons): `.tmp-*`, `_site/`, `node_modules/`, and Python bytecode caches, so a pipeline or test that creates one does not dirty the tree.
* [x] add the skeleton drift detector and the append-not-fork rule (2026-09-24; Tier 2 from the recent-project lessons): derived projects froze their prompt copies at fork, so a project's stated rules could contradict its scripts.
    * [x] `scripts/skeleton-diff.sh` reports rule-file drift (fatal) and reference-artifact adaptation (informational) between a project and the skeleton; it already finds real drift in elseon and gnome.
    * [x] `tests/08-skeleton-diff.sh` covers clean, rule drift, and adaptation.
    * [x] `README.md` gains "Keeping Current with this Skeleton"; conventions §5 says to append a project section instead of forking shared text.
* [x] encode the publishing lessons (2026-09-24; Tier 2 from the recent-project lessons):
    * [x] the shared nav must be depth-adjusted (`../` per level) for a page below the project root, applied to the nav block only.
    * [x] replace the skeleton's placeholder `index.txt`/`dashboard.txt` before registering; a placeholder publishes a project that does not exist.
    * [x] generate the dashboard from live state, never hand-typed values.
    * [x] every served asset URL carries a content token, including transitive imports; the build fails when the stamp misses.
    * [x] landed in `prompts/features/01-site-build.md`, `prompts/features/02-project-pages.md`, `documents/06-project-pages.md`, and `prompts/03-conventions.md` §6.
* [x] add the research and decision-record guidance (2026-09-24; Tier 2 from the recent-project lessons): `prompts/how-to-write-research.md` defines one criteria file with a changelog, one study per candidate with fixed headings and evidence rules, the fan-out-then-synthesize method, the durable survey index, and the dated options-ladder decision record; registered in `prompts/README.md`.
* [x] ship the suggested episode plan (2026-09-24; Tier 2 from the recent-project lessons): `prompts/episodes/02-episode-plan.md` breaks `PHASES.md` into suggested episodes, named by phase and letter so dispatch-time renumbering cannot invalidate it; registered in `prompts/episodes/00-episodes.md` and referenced from `prompts/how-to-write-episodes.md` §9.
* [x] encode the record-keeping lessons (2026-09-24; Tier 2 from the recent-project lessons): `records/README.md` gains the two-commit rule for a record's own hash, the fails-against-old-code regression rule, the do-not-quote-the-gate rule, date-prefixed filenames, unattributable-drift handling, and "unexplained is a result"; `prompts/02-workflow.md` §7.1/§7.2 and `prompts/common/02-universal-rules.md` carry the matching rules.
* [x] organize the test suite (2026-09-24; Tier 2 from the recent-project lessons):
    * [x] `scripts/tests-run.sh` runs every test and reports `PASS`/`FAIL` with a summary, instead of stopping at the first failure.
    * [x] `tests/lib/test_helpers.sh` holds the shared skip/fail/pass helpers; `tests/05`–`07` use `skip_unless_tool`.
    * [x] `tests/README.md` documents the reserved number bands, the helper directory, the sandbox rule, and the fixture rule.
    * [x] `prompts/02-workflow.md` §4.1/§4.2 encode the skip idiom and the organization rules.
* [x] add the release and pinned-dependency conventions (2026-09-24; Tier 2 from the recent-project lessons): `prompts/capabilities/04-release-and-publishing.md` encodes publish gating, deterministic packing, versionless asset names, checksums/version/notes, installer rules, atomic install, and re-runnable publishing; `prompts/capabilities/05-pinned-dependencies.md` covers pinning a dependency to a tag and asserting the pin.
    * [x] ship `scripts/release-gate.sh` (refuses a dirty tree, a `-changes` version, and a version that does not name HEAD) and `tests/07-release-gate.sh`.
* [x] add the generated-data-product conventions (2026-09-24; Tier 2 from the recent-project lessons): `prompts/capabilities/03-generated-data-products.md` encodes numbered stages and work products, reuse/`--refresh`/`--retry-failed`, file-named make rules, the no-dead-placeholder rule, a cheap `all` target, raw caches with provenance, `manifest.json`, `check`/`--check`, manual `clean` for expensive outputs, independent verification, and units in exchange formats.
    * [x] model the `all` target in the skeleton `Makefile` (defaults to `build`).
* [x] preserve nested lists in the condensed `todo.html` (2026-09-24; Tier 1 from the recent-project lessons): the old renderer flattened them and counted only lowercase, top-level completed items.
    * [x] `scripts/site-condense.sh` renders nesting with an indentation stack; completed items (`[x]` or `[X]`) are counted, never listed.
    * [x] `tests/06-todo-condense.sh` (tool-gated on python3) covers nesting, continuation lines, the counts, and balanced markup.
* [x] extend the site-build contract and its worked example (2026-09-24; Tier 1 from the recent-project lessons): the feature doc omitted asset pass-through, live state, generated artifacts, and deterministic trees that six projects already implement.
    * [x] `scripts/site-build.sh` copies authored assets verbatim and excludes `template.html` and `pages.nav`.
    * [x] `prompts/features/01-site-build.md` states the asset, live-state, generated-artifact, and deterministic-tree rules.
    * [x] ship an example `site.in/pages.nav`, and assert the asset copy and the two exclusions in `tests/01-site-build.sh`.
* [x] ship `scripts/version-generate.sh` (2026-09-24; Tier 1 from the recent-project lessons): `prompts/capabilities/02-version-information.md` names it canonical, but the skeleton shipped no implementation.
    * [x] generalized from the gnome-appimage-integration implementation; writes `dataflow.out/build/generated/version_info.h` and the gitignored build counter.
    * [x] `tests/05-version-generate.sh` (tool-gated on git) checks the `date-branch-hash` shape, the tag and `-changes` suffixes, and the counter.
* [x] register `PHASES.md` as a required root file (2026-09-24; Tier 1 from the recent-project lessons): the project-pages conventions depend on it, but the README map, the Canonical Files list, and the skeleton test omitted it.
    * [x] add it to the `README.md` top-level map and Canonical Files.
    * [x] require it in `tests/00-skeleton.sh`.
    * [x] add the keep-it-current rule to `prompts/03-conventions.md` §6.
* [x] build hygiene: start the site build from an empty output tree, and make `clean` remove directories (2026-09-24; Tier 1 from the recent-project lessons):
    * [x] `scripts/site-build.sh` clears `site.out/` first (keeping `.gitkeep`), so a renamed or removed page cannot linger as a published orphan.
    * [x] `make clean` uses `rm -rf`, so a pipeline's output subdirectories are actually removed (the old `rm -f` failed on a directory).
    * [x] `tests/01-site-build.sh` seeds a stale page and the placeholder and asserts the page is removed and the placeholder kept.
* [x] make the `PHASES.md` parser tolerant and validating (2026-09-24; Tier 1 from the recent-project lessons):
    * [x] `scripts/site-condense.sh` now takes the state as the last dash field, so `Current: phase N — <description> — state` parses (gnome's line did not, and lost its phase silently).
    * [x] an unknown state leaves `phase.txt` unwritten with a warning instead of emitting a wrong phase.
    * [x] `tests/04-phase-parse.sh` covers the descriptive form, the short form, and the invalid state.
* [x] add the sanitization gate the conventions required but the skeleton did not ship (2026-09-24; Tier 1 from the recent-project lessons):
    * [x] `scripts/sensitive-patterns.sh` is the single source of the publish patterns; never inline them elsewhere.
    * [x] `scripts/leak-gate.sh` refuses leaks over a file or tree and prints the first matches.
    * [x] `tests/03-leak-gate.sh` covers clean content (public IPs, `## 10.` headings), refused content, a missing path, and single-source drift.
    * [x] encode the rule in `prompts/03-conventions.md` §6, `prompts/features/02-project-pages.md`, and `documents/06-project-pages.md`.
* [x] add the live-state mechanism the project-pages conventions already named (2026-09-24; Tier 1 from the recent-project lessons):
    * [x] `scripts/site-state-fetch.sh` (`make state`) writes `dataflow.out/site-state.txt` as `KEY=value` lines, sanitized at capture.
    * [x] `scripts/site-build.sh` substitutes `__KEY__` placeholders from the state file; a key with no value renders as `unavailable`.
    * [x] `site.in/dashboard.txt` is a live-state example; `documents/06-project-pages.md` and `prompts/features/02-project-pages.md` document the mechanism.
    * [x] `tests/01-site-build.sh` covers substitution and the portable fallback.
* [x] repair skeleton inconsistencies: `logs/`, `.gitkeep` files, `make test` wiring.
* [x] add worked example: Site Build feature, task, script, input, and tests.
* [x] harden the workflow: Definition of Done, git commit step, verification-failure loop.
* [x] define the workflow for "tasks" versus "features".
    * [x] should long form tasks be in `prompts/tasks/` and follow the `prompts/how-to-write-tasks.md` guidance?
    * [x] should there be guidance for how to write features in `prompts/how-to-write-features.md`?

* [x] include a map of the prompts in `prompts/README.md` if missing
* [x] include top-level map of project in `README.md` if missing

- [x] Create project structure.
- [x] Write initial prompts.
* [x] study `prompts/flavors/01-semantic-sort-naming.md` and remove similar naming rules from other prompts.
* [x] capture the interaction-pattern conversation in `documents/00-pattern-of-interaction.md`.
* [x] add the async-worktree worked example in `documents/01-async-worktree.md`.
* [x] add the tool-universe survey in `documents/02-tool-universe.md`.
* [x] add `prompts/how-to-write-episodes.md` and `prompts/episodes/01-episode-template.md`.
* [x] establish the intent/record separation with `records/README.md`.
* [x] register `documents/` and `records/` in the contract, conventions, README map, and skeleton test.
* [x] extract the site-build HTML structure into `site.in/template.html`.
* [x] use UPPERCASE names for constant shell variables in scripts and tests.
* [x] apply semantic-sort naming to shell constant variables.
* [x] apply type-prefix naming to shell variable names.
* [x] incorporate the homelab lessons into the skeleton (2026-08-23):
    * [x] add outcome, incident, and handoff record forms to `records/README.md`.
    * [x] add risky-operations and privacy-boundary rules to `prompts/common/02-universal-rules.md`.
    * [x] add test tiers (portable, tool-gated, live-state) to `prompts/02-workflow.md` §4.1.
    * [x] add generated-documentation and live-state-verification conventions to `prompts/03-conventions.md`.
    * [x] add skeleton-startup guidance and privacy-boundary note to `README.md`.
    * [x] add the worktrees-versus-records section to `documents/00-pattern-of-interaction.md`.
    * [x] add `documents/04-lessons-from-homelab.md` and register it in `documents/README.md`.
    * [x] note in `prompts/features/00-features.md` that bundled features are examples.
* [x] incorporate the homelab project-pages publishing conventions (2026-08-25):
    * [x] standard page set: rename `hello.txt` to `index.txt` (status page), add
          `dashboard.txt`, standard 5-page nav in `site.in/template.html`.
    * [x] add `scripts/site-condense.sh` (todo/prompts/documents generator, from the
          MI25 fan-service) and wire `make site` (`site-build.sh` + `site-condense.sh`).
    * [x] retire `make deploy` — publishing goes through the homelab (homelab-publish).
    * [x] add `documents/06-project-pages.md` (conventions summary) and
          `prompts/features/02-project-pages.md` (feature).
* [x] capture the MI25 fan-service project process lessons (2026-08-24):
    * [x] encode the record-update rule: when a task changes a status, update the
          referenced record in the same commit (the MI25 record `09-project-site.md`
          said "not yet implemented" after the deployment was live).
    * [x] document that generated build trees are path-bound: clean them when the
          repository is reached through a different path (SSHFS vs native mount; a
          stale CMakeCache broke the MI25 build after the mount path changed).
    * [x] add timestamped test-run logging to `scripts/tests-run.sh` (the MI25
          project writes `logs/YYYY-MM-DD-HH-MM-SS-test-run.log`).
* [x] decide the site-build approach: literal text-to-HTML, Markdown-to-HTML, or a static-site generator such as 11ty.
      — **Decided 2026-08-23 by the homelab exercise**: the literal text-to-HTML site-build is kept as the minimal
      worked example; a real site used Eleventy (a static-site generator); model-driven documents use a custom
      generator with a provenance header. Encoded in `prompts/capabilities/01-generated-documentation.md`.

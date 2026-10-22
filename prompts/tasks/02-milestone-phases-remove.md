# Task: Remove the Milestone-Phase Notion

## TASK-DESCRIPTION
Remove the project-milestone "phase" notion from the skeleton.
An episode is the unit of progress; progress is a series of episodes, often with tasks discovered along the way.
The "response phases" in `prompts/01-contract.md` section 4 (Clarification, Planning, Implementation, Verification, Correction) are a different concept and stay.

- Delete: `PHASES.md`
- Delete: `tests/04-phase-parse.sh`
- Modify: `prompts/01-contract.md`
- Modify: `prompts/02-workflow.md`
- Modify: `prompts/03-conventions.md`
- Modify: `prompts/how-to-write-episodes.md`
- Modify: `prompts/episodes/01-episode-template.md`
- Modify: `prompts/episodes/02-episode-plan.md`
- Modify: `prompts/episodes/00-episodes.md`
- Modify: `README.md`
- Modify: `AGENTS.md`
- Modify: `scripts/status.sh`
- Modify: `scripts/site-condense.sh`
- Modify: `scripts/prompt-maturity.sh`
- Modify: `tests/00-skeleton.sh`
- Modify: `tests/09-prompt-contract.sh`
- Modify: `tests/10-prompt-validator.sh`
- Modify: `tests/12-status.sh`
- Modify: `documents/06-project-pages.md`
- Modify: `site.in/index.txt`
- Modify: `evals/05-acceptance-remains-human.md`

The edit for each file:

- `prompts/01-contract.md`: remove the `PHASES.md` bullet from the section 7 canonical root files, and reword the section 2 row for `prompts/episodes/02-episode-plan.md` from "when work is planned by phase" to "when work is planned".
- `prompts/02-workflow.md`: in section 4, drop "and phase state" from the sentence naming what the prompt-contract test validates.
- `prompts/03-conventions.md`: remove the "Keep `PHASES.md` current" rule from section 6.
- `prompts/how-to-write-episodes.md`: remove section 9 "Relationship to Phases" in full, then renumber the following sections (10 to 9, 11 to 10, 12 to 11, 13 to 12).
- `prompts/episodes/01-episode-template.md`: remove the optional `EPISODE-PHASE` field.
- `prompts/episodes/02-episode-plan.md`: rewrite as a flat suggested-episodes list with no "Phase 1 / Phase 2" grouping, no phase-order dependency rule, and no phase-and-letter naming.
- `prompts/episodes/00-episodes.md`: reword the index line for `02-episode-plan.md` to drop "of the phases".
- `README.md`: remove the `PHASES.md` line from the top-level map and from the Canonical Files list.
- `AGENTS.md`: drop `PHASES.md` from the state line, and drop "the current phase" from the `make status` description.
- `scripts/status.sh`: remove the block that prints `== phase:`, and reword the header comment.
- `scripts/site-condense.sh`: remove the `phase.txt` generation block.
- `scripts/prompt-maturity.sh`: drop `PHASES.md` from the durable-memory condition and from its description.
- `tests/00-skeleton.sh`: remove `PHASES.md` from `FILES_REQUIRED`.
- `tests/09-prompt-contract.sh`: remove check 7 (the PHASES.md validation) and its header mention; leave the remaining check numbers unchanged.
- `tests/10-prompt-validator.sh`: remove the `FILE_PHASES` variable and the three check-7 fixtures; reword the section comment.
- `tests/12-status.sh`: remove the PHASES.md fixture and the phase assertions; keep the TODO, log, and git assertions, with a phase-free TODO example.
- `documents/06-project-pages.md`: remove the "activity vs phase" passage and the `site.out/phase.txt` references.
- `site.in/index.txt`: drop "phases" from the status placeholder sentence.
- `evals/05-acceptance-remains-human.md`: reword the example task instruction to reference the TODO line instead of a phase line.

## TASK-OUTPUT
* Report each deleted and modified file, and the `make test` result.
* End with the `VERIFICATION:` line.

## TASK-CONTEXT
<note>
The notion being removed is the project-milestone phase: `PHASES.md`, the `Current: phase N` line, the `site.out/phase.txt` output, and the `EPISODE-PHASE` field.
The response phases in `prompts/01-contract.md` section 4 are separate and remain.
After removing validator check 7, leave the remaining check numbers unchanged; a gap is acceptable because `tests/13-corpus-coverage.sh` compares the declared checks against the used fixtures, not a sequence.
Do not rewrite `TODO.md`: its phase mentions are historical changelog entries, not rules.
Do not modify `tests/13-corpus-coverage.sh` or `scripts/tests-run.sh`: the first reconciles automatically, and the second globs `tests/*.sh`.
</note>

## TASK-FILES

| Operation | Path |
|---|---|
| delete | `PHASES.md` |
| delete | `tests/04-phase-parse.sh` |
| modify | `prompts/01-contract.md` |
| modify | `prompts/02-workflow.md` |
| modify | `prompts/03-conventions.md` |
| modify | `prompts/how-to-write-episodes.md` |
| modify | `prompts/episodes/01-episode-template.md` |
| modify | `prompts/episodes/02-episode-plan.md` |
| modify | `prompts/episodes/00-episodes.md` |
| modify | `README.md` |
| modify | `AGENTS.md` |
| modify | `scripts/status.sh` |
| modify | `scripts/site-condense.sh` |
| modify | `scripts/prompt-maturity.sh` |
| modify | `tests/00-skeleton.sh` |
| modify | `tests/09-prompt-contract.sh` |
| modify | `tests/10-prompt-validator.sh` |
| modify | `tests/12-status.sh` |
| modify | `documents/06-project-pages.md` |
| modify | `site.in/index.txt` |
| modify | `evals/05-acceptance-remains-human.md` |

## TASK-VERIFY
- Run: `make test` from the repository root.
- Expected: exit status 0.

OUTPUT: the deleted and modified files and the `make test` result, ending with the `VERIFICATION:` line.

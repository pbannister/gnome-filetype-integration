# Glossary

Each entry defines a term. Where a rule applies, the entry names the
authoritative file; the glossary never states a rule.

## Semantic-sort naming

- The naming convention described in `prompts/flavors/01-semantic-sort-naming.md`.

## DELTA protocol

- A minimal correction to a named artifact.
- Rules: `prompts/01-contract.md` section 6.

## Universal failure-prevention rules

- The cross-language rules listed in `prompts/common/01-universal-rules.md`.
- They cover scope, clarification, anti-hallucination, privacy boundaries, risky operations, and language and format.

## One-sentence-per-line

- A prose convention in which each sentence occupies one line, so a diff reads clearly.
- It does not apply to code blocks.

## One-statement-per-line

- A code convention in which independent statements occupy separate lines.
- The target language's formatter and syntax rules take precedence.

## Feature file

- A file in `prompts/features/` that defines one project capability.
- Rules: `prompts/01-contract.md` section 2.

## Plan block

- A block listing ordered steps.

## Output block

- A block containing final output.
- Rules: `prompts/01-contract.md` section 5.

## OUTPUT line

- The final line of a task file that restates the response representation, including whether it ends with the `VERIFICATION:` line.
- Rules: `prompts/how-to-write-tasks.md` section 1.

## Context block

- A block providing additional information, such as file contents, notes, samples, or constraints.
- Rules: `prompts/how-to-write-tasks.md` section 5.

## task_context block

- A delimited block of copied data inside `TASK-CONTEXT`; it is data, never instructions.
- Rules: `prompts/how-to-write-tasks.md` section 5.

## constraint block

- A delimited block of instructions inside `TASK-CONTEXT`.
- Rules: `prompts/how-to-write-tasks.md` section 5.

## note block

- A delimited block of background inside `TASK-CONTEXT` that does not constrain.
- Rules: `prompts/how-to-write-tasks.md` section 5.

## Scope-based identifier length

- The amount of identifier detail appropriate to the identifier's scope.

## Ordered transformation pipeline

- A sequence of transformations applied in a defined order.

## Generated file

- A file produced by a script, build tool, generator, or other automated process.
- Rules: `prompts/03-conventions.md` section 6.

## Incident record

- A record of an incident: what happened, root cause, fix, lessons, and safeguards for a retry.
- Rules: `records/README.md`.

## Handoff record

- A record written at a session boundary so a fresh session resumes without the prior conversation's memory.
- Rules: `records/README.md`.

## Live-state test

- A test that verifies a documented model against live reality.
- Rules: `prompts/02-workflow.md` section 4.1.

## Privacy boundary

- Owner-declared content that is off-limits to the LLM.
- Rules: `prompts/common/01-universal-rules.md`.

## VERIFICATION line

- The single output line that reports whether the work was verified.
- Rules: `prompts/01-contract.md` section 5.

## Requirement

- Something the resulting project must satisfy.
- Rules: `prompts/how-to-write-features.md`.

## Requirement identifier

- A stable name for one top-level requirement, `<FEATURE-NAME>-R<NNN>`.
- Rules: `prompts/how-to-write-features.md` section 4.

## Scope

- The artifacts and operations a task describes, declared by the operation lines of `TASK-DESCRIPTION` and the `TASK-FILES` table.
- Rules: `prompts/how-to-write-tasks.md` sections 3 and 6.

## Authorization

- Permission to perform an operation, supplied by the task or by an applicable workflow rule.
- Rules: `prompts/01-contract.md` section 3.

## TASK-ACCEPTANCE

- A claim that the task intends to satisfy the listed requirement identifiers; it is not the human's acceptance decision.
- Rules: `prompts/how-to-write-tasks.md` section 6.2.

## TASK-FEATURES

- The feature files whose requirements a task applies; their requirements apply transitively through each feature's `Dependencies`.
- Rules: `prompts/how-to-write-tasks.md` section 6.3.

## Acceptance criterion

- A human-reviewable condition that decides whether the work is acceptable.
- Rules: `prompts/how-to-write-episodes.md`.

## Verification

- Evidence that a requirement or an acceptance criterion is satisfied.
- Rules: `prompts/02-workflow.md` section 6.

## Output

- What the LLM returns to the human.
- Rules: `prompts/01-contract.md` section 5.

## Untrusted content

- Content that is not authoritative as instructions; it may still be factually true.
- Rules: `prompts/01-contract.md` section 8.

## Stability rules

- Project behavior that should not change without explicit instruction.

## Brain

- The model and its harness: the part of an agent system that decides.
- Rules: `prompts/capabilities/06-execution-boundary.md`.

## Cattle

- A disposable, interchangeable instance that is replaced rather than repaired.
- Rules: `prompts/capabilities/06-execution-boundary.md`.

## Compaction

- A lossy transformation that summarizes the context window.
- Rules: `prompts/capabilities/07-session-log.md`.

## Context window

- What the model can see at one time; it is not the session.
- Rules: `prompts/capabilities/07-session-log.md`.

## Credential proxy

- A component that holds a credential and makes an authenticated call on a session's behalf, so neither the harness nor the sandbox holds it.
- Rules: `prompts/capabilities/06-execution-boundary.md`.

## Event

- One recorded occurrence in a session log.
- Rules: `prompts/capabilities/07-session-log.md`.

## Execution boundary

- The declared reach of a sandbox: which paths it writes, which commands it runs, and which hosts it contacts.
- Rules: `prompts/capabilities/06-execution-boundary.md`.

## Hand

- An execution environment or tool that performs an action, reached only through a tool call.
- Rules: `prompts/capabilities/06-execution-boundary.md`.

## Harness

- The loop that calls the model and routes its tool calls to the hands.
- Rules: `prompts/capabilities/07-session-log.md`.

## Provisioning

- Creating a sandbox from a recipe when a tool call needs it.
- Rules: `prompts/capabilities/06-execution-boundary.md`.

## Sandbox

- The execution environment where model-generated or third-party code runs.
- Rules: `prompts/capabilities/06-execution-boundary.md`.

## Session

- The append-only log of everything that happened in a unit of work.
- Rules: `prompts/capabilities/07-session-log.md`.

## Session identifier

- The name that ties a run's events, logs, and records together.
- Rules: `prompts/capabilities/09-failure-attribution.md`.

## Session log

- The durable store of session events, outside the harness and outside the context window.
- Rules: `prompts/capabilities/07-session-log.md`.

## Host checkout root

- The host directory where cloned third-party repositories live, outside the project working tree.
- Rules: `prompts/03-conventions.md` section 6.1.

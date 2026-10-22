# Prompt Maturity

This document rates the prompt protocol against the practices that coding-agent
work has converged on. It is a self-assessment, not a gate.

## The Scale

Each dimension is scored 0 to 3. The level is about evidence, not intent.

- 0 — absent.
- 1 — documented as prose; a reader could follow it, nothing checks it.
- 2 — enforced mechanically; a script refuses a violation.
- 3 — enforced and measured; a regression is caught by a check that runs.

A dimension cannot reach 3 without a test that fails when the property breaks.
Prose that claims a property does not raise the score.

## The Dimensions

| Dimension | 3 requires | Typical 2 | Typical 1 |
|---|---|---|---|
| Entry point | a conventional entry file, checked by the validator | the file exists | described in the README |
| Context budget | the baseline size is measured and bounded | baseline plus task-relevant load | one undivided rules file |
| Authority | one home per rule, duplicates rejected, coverage enforced | duplicates rejected | rules restated in several files |
| Scope and authorization | operations enumerated and cross-checked | operations enumerated | scope described in prose |
| Feedback loop | one command, an observable result, and a report the agent cannot fake | the command exists | the command is documented |
| Durable memory | state files plus the record forms | some state files | conversation only |
| Safety | untrusted content handled and an injection corpus | untrusted content rules | rules only for secrets |
| Behavioral evals | a scored model run repeats on every prompt change | frozen cases, scored by hand | none |
| Prompt-change discipline | a rule change cannot land without its test | tests exist | review only |
| Parallel work | isolation plus the delegation authority of a subagent | isolation only | one writer assumed |

## Scoring This Project

Run `make maturity` (`sh scripts/prompt-maturity.sh`). It computes the
machine-checkable subset and prints each dimension with its ceiling. The script
is deliberately unable to award the top score for behavioral evals, because a
scored model run is not measured automatically. A ceiling below 3 is the
finding.

Two dimensions earned the top score by acquiring evidence rather than prose:

- Context budget: `prompts/02-workflow.md` section 1 declares
  `Always-loaded context budget: <N> bytes`, and `make context`
  (`sh scripts/context-budget.sh`) measures the entry point plus the mandatory
  baseline against it. The optional capability conventions live in
  `prompts/capabilities/` and are loaded only for a task that touches one, so
  they no longer sit in the always-loaded path.
- Safety: the contract denies a task any operation on a protected path and the
  validator refuses such a task, while `evals/04-prompt-injection.md` covers the
  behavioral half.

The manual remainder is judgment:

- Does the baseline load order match what a task actually needs? A rule that no
  task ever consults is context cost without benefit.
- Does an eval case fail for a reason the protocol predicted? A failure the
  protocol does not explain is a gap in the protocol, not only in the agent.

## Rules

- Raise a dimension by adding the missing evidence; never by editing a score.
- An eval pass raises confidence; it does not prove correctness. Prompts
  constrain probability, not behavior.
- Delete a rule that no longer changes behavior. Context cost is real, and a
  stronger model needs less of it.
- Add a rule only after a task fails without it; then add the check that would
  have caught the failure.
- Audit the baseline before adding to it: name the task that fails without the
  new rule.

## Context Audit

The budget makes growth visible; this procedure decides what stays.

- Run `make context` and take the largest section in the report.
- For that section's rules, name the task that fails without them.
- A rule with no such task is deleted, not kept for comfort.
- A rule that only some tasks need moves to `prompts/capabilities/`, or to the
  task-relevant load in `prompts/02-workflow.md` section 1.
- Lower the declared budget when the baseline shrinks; raise it only
  deliberately, in the same change that adds the rule.

An audit is judgment, so let the evals arbitrate: remove a candidate rule, run
the cases, and see whether any behavior degrades.

Worked example, 2026-10-11: the capability block was 45% of the largest
always-loaded file and already labelled `(capability)`, so it moved to
`prompts/capabilities/`. A table of contents, two rule files with no unique
rule, and three restated rules went with it. The baseline fell from 46,212 to
39,477 bytes with no rule lost.

Worked example, 2026-10-15: a review against Anthropic's *Scaling Managed
Agents: Decoupling the brain from the hands*
(https://www.anthropic.com/engineering/managed-agents) found that the corpus
governed what the agent is told and what it writes, and almost nothing about
what it can reach. Four capability files joined the corpus
(`06-execution-boundary.md`, `07-session-log.md`, `08-delegation-authority.md`,
`09-failure-attribution.md`), and the parallel-work dimension reached 3 because
the delegation rule now has a registered home that the validator holds.
Capability scoping kept the always-loaded baseline flat except for the four
Applicability lines, which is the pattern to repeat: new axes of concern enter
as capability files, not as baseline.

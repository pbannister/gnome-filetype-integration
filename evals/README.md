# README for evals

Behavioral evaluation cases for a real coding agent live here.

An eval is a frozen case: a task handed to a real agent, plus observable
expected behavior, scored by a human.

## What an Eval Is Not

- An eval is not a unit test. The tests under `tests/` validate the prompt
  artifacts; none of them can show how a model behaves.
- An eval is not deterministic. A pass raises confidence; it does not prove
  correctness.
- An eval never gates a commit. It informs a change to `prompts/`.

## When to Run

Run the cases after any change to a file under `prompts/`, and before adopting
that change. Run a single case when its behavior is the one at risk.

## How to Run One Case

1. Open the case file and copy the task text from `## Task given to the agent`.
2. Hand that text to the agent as the task, in a scratch checkout or worktree
   (`prompts/02-workflow.md` section 3.1).
3. Let the agent work to completion.
4. Score every criterion in `## Scoring` as pass or fail, with the observation
   that decided it.

## How to Score

- Each criterion is pass or fail; there is no partial credit.
- Record `passed N of M` for the case.
- An unobservable claim by the agent is a fail, not a pass.

## Where Results Go

- Record the result in a `records/` outcome, incident, or handoff record; see
  `records/README.md`. Do not invent a record type for evals.
- A failure is a prompt defect. Fix the defect under `prompts/`, then add the
  check or fixture that would have caught it.

## Case Format

Each case file carries these headings, in this order:

- `## Case` — the behavior under test and why it matters.
- `## Task given to the agent` — the literal text to hand the agent.
- `## Expected behavior` — observable behaviors, one per bullet.
- `## Failing signals` — the observable defects that mean failure.
- `## Scoring` — the pass/fail criteria.

## Limits

- A case tests one behavior; a pass says nothing about the others.
- A model change, a tool change, or a larger context can change a result.
- The set is small on purpose. Add a case only for a behavior that failed, or
  that a change put at risk.

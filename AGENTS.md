# Agent Entry Point

This file is the entry point for a coding agent working in this repository.
It is orientation only: it points at the authoritative files and defines no
rule of its own. Where this file and an authoritative file differ, the
authoritative file governs (`prompts/01-contract.md` section 2).

## Read First

- `prompts/01-contract.md` — authority, precedence, interaction, output, safety.
- `prompts/02-workflow.md` — the execution sequence; its section 1 lists the
  mandatory baseline, in order, and the task-relevant files to load after it.
- `prompts/03-conventions.md` — formatting, naming, and repository structure.

## Then

- The task: `prompts/how-to-write-tasks.md` defines the format a task must
  have.
- The feature requirements the task references: `prompts/features/`.
- The state: `TODO.md` (status, not authorization).
- The record forms: `records/README.md`.

## Commands

- `make test` — the repository check suite; it writes a log under `logs/`.
- `make status` — the next open TODO item, the last test result, and the
  working-tree state, in one screen.
- `make site`, `make release`, `make install` — see the `Makefile`.

## Tool-Specific Files

- A tool-specific file (`.aider.conf.yml`, `CLAUDE.md`,
  `.github/copilot-instructions.md`, or similar) points here or holds
  mechanical configuration; it must not restate a rule.
- `prompts/` is the only place a rule is defined.

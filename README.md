# Project Overview

- This repository is structured for collaborative development with a Large Language Model (LLM).
- This file `README.md` is located at the root of the project structure.

A coding agent begins at `AGENTS.md`, the tool-neutral entry point. The full
mandatory load order is in `prompts/02-workflow.md` section 1:

- `prompts/01-contract.md` defines the interaction, authority, and safety rules.
- `prompts/02-workflow.md` defines the execution sequence for every task.
- `prompts/03-conventions.md` defines formatting and repository conventions.

- The LLM must follow the workflow defined in `prompts/02-workflow.md` for every task.

Human contributors should begin by reading:

- `prompts/README.md`
- `documents/README.md`

Note there are rules meant only to constrain Aider behavior:

- `tools/aider-rules.md` (Aider users only)

All project features are defined in `prompts/features/` and implemented in `sources/`.

## Top-Level Map

- `README.md` is the project overview.
- `AGENTS.md` is the coding-agent entry point; it points at `prompts/` and defines no rule.
- `TODO.md` tracks pending and completed project tasks.
- `prompts/` contains LLM interaction rules, common requirements, feature requirements, task definitions, and episode work orders.
- `documents/` contains human-consumption documents: the interaction pattern, worked examples, and tool notes.
- `records/` contains version-controlled outcome, incident, and handoff records.
- `tools/` contains tool-specific rules.
- `tools/aider-rules.md` is used only with Aider.
- `sources/` contains implementations.
- `scripts/` contains project scripts.
- `tests/` contains tests and validation code.
- `evals/` contains behavioral evaluation cases for a real agent, scored by hand; see `evals/README.md`.
- `dataflow.in/` contains input data.
- `dataflow.out/` contains generated data output (not version-controlled).
- `logs/` contains generated logs (not version-controlled).
- `site.in/` contains static-site input.
- `site.out/` contains generated static-site output (not version-controlled).
- `Makefile` drives the build (`make build`), the tests (`make test`), and cleanup (`make clean`).

## Project Settings

- Automatic task commits: enabled (see `prompts/02-workflow.md` §7.1). A derived project that owns its commits sets this to disabled.

## Worked Example

The repository includes one worked example that exercises the whole workflow:

- Feature: `prompts/features/01-site-build.md`
- Task: `prompts/tasks/01-site-build-implement.md`
- Script: `scripts/site-build.sh` generates `site.out/` from `site.in/`.
- Tests: `tests/00-skeleton.sh` and `tests/01-site-build.sh`
- Input: `site.in/index.txt` (status page) and `site.in/dashboard.txt`
- Template: `site.in/template.html` provides the HTML page structure.

- Run `make build` to generate the site and `make test` to run the tests.
- The bundled feature is a worked example, not a requirement.
- A new project keeps, trims, or repurposes it; real sites have used a static-site generator instead.

## Project Pages (publishing conventions)

- A project derived from this skeleton publishes the standard page set
  (status, dashboard, condensed todo/prompts/documents) per
  `prompts/features/02-project-pages.md` and
  `documents/06-project-pages.md`.
- `make site` builds the full set (`scripts/site-build.sh` +
  `scripts/site-condense.sh`).
- Publishing goes through the homelab project (homelab-publish): the project
  registers once via `pages_source` and does not push to the web server
  itself — `make deploy` is retired.

## Starting a New Project from this Skeleton

- Copy the repository, then decide what to keep, trim, or repurpose.
- Review `prompts/features/` and trim features the project does not need.
- Replace the placeholder `site.in/index.txt` and `site.in/dashboard.txt` with the project's own pages, and replace the `index` case in `scripts/site-build.sh` `page_title()`; a published placeholder describes a project that does not exist.
- Declare owner privacy boundaries (off-limits content) in the README or a dedicated document; the LLM treats them as authoritative scope exclusions.
- Adopt the test tiers in `prompts/02-workflow.md`; declare live-state tests and their prerequisites.
- Use records for outcomes, incidents, and handoffs; see `records/README.md`.
- Choose the concurrency model: git worktrees for parallel multi-thread development, checkpoint and handoff records for serial work against live systems.
- Delete this "Starting a New Project from this Skeleton" section from the derived project; it does not apply there.
- See `documents/04-lessons-from-homelab.md` for the lessons that shaped these rules.

## Keeping Current with this Skeleton

- A derived project keeps its own copy of the shared rule files (`prompts/`, the directory READMEs, the reference scripts, and the template); those copies drift as the skeleton evolves.
- `scripts/skeleton-diff.sh <project-dir>` reports how a project's shared files differ from this skeleton. Rule-file drift is a failure; drift in the reference scripts and template is expected when a project adapts them.
- Customize a shared rule document by appending a project section (for example `## How this project does it`) and leaving the shared text intact. Do not fork it, so the next re-sync stays a small diff.

## Canonical Files

The following filenames are canonical and must not be renamed or duplicated without an explicit task:

- `README.md`
- `AGENTS.md`
- `TODO.md`
- `Makefile`
- `package.json`
- `.gitignore`

Tool-specific root files (for example `.aider.conf.yml`, `.aiderignore`) are permitted when a file under `tools/` declares them; see `prompts/01-contract.md` section 7.

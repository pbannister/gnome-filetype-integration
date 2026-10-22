# Prompt Corpus Mind-Map

A visual map of the `prompts/` corpus, grouped by role and load condition.

The always-loaded baseline applies to every task.
The capability, language-flavor, and authoring-guide files load only when a task touches them.
The feature, task, and episode files are dispatched work, not standing rules.

```mermaid
mindmap
  root((prompts/))
    Always-loaded baseline
      01-contract.md
      02-workflow.md
      03-conventions.md
      common/02-universal-rules.md
      flavors/01-semantic-sort-naming.md
    Capabilities (load only when touched)
      capabilities/01-generated-documentation
      capabilities/02-version-information
      capabilities/03-generated-data-products
      capabilities/04-release-and-publishing
      capabilities/05-pinned-dependencies
    Language flavors
      flavors/01-semantic-sort-naming
      flavors/02-cpp-conventions (C++)
    Authoring guides (how-to-write-*)
      how-to-write-tasks
      how-to-write-features
      how-to-write-episodes
      how-to-write-research
    Feature requirements
      features/00 index
      features/01-site-build (worked example)
      features/02-project-pages
    Task definitions
      tasks/00 index
      tasks/01-site-build-implement (worked example)
    Episodes
      episodes/00 index
      episodes/01 template
      episodes/02 plan
    Glossary (reference, no rule)
      common/03-glossary.md
```

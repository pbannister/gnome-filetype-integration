# Prompt Relations Graph

A knowledge graph of how the prompt files relate: authority, load order, references, feature traceability, and the mechanical checks that enforce them.

Solid arrows are structural edges.
Dotted arrows are authority pointers to a single home.
The dashed cluster holds the scripts and tests that make the graph mechanical instead of aspirational.

```mermaid
flowchart TD
  subgraph DESC["Descriptive — context, defines no rule"]
    README["README.md"]
    AGENTS["AGENTS.md<br/>(tool-neutral entry point)"]
    DOCS["documents/*.md<br/>(rationale + field lessons)"]
    GLOSS["common/03-glossary.md"]
  end

  subgraph CONV["Conventions"]
    C3["03-conventions.md"]
    F1["flavors/01-semantic-sort-naming"]
    F2["flavors/02-cpp-conventions (C++)"]
    CAP["capabilities/01..05"]
    HT["how-to-write-tasks / -features / -episodes / -research"]
    EP["episodes/01-template, 02-plan"]
    REC["records/README.md"]
    TR["tests/README.md"]
    TOOLS["tools/*.md (per-tool)"]
  end

  subgraph GLOBAL["Global requirements"]
    UNIV["common/02-universal-rules"]
  end

  subgraph FEAT["Feature requirements"]
    FEAT1["features/01-site-build<br/>(worked example)"]
    FEAT2["features/02-project-pages"]
  end

  subgraph WF["Workflow"]
    W2["02-workflow.md"]
  end

  subgraph CT["Contract"]
    C1["01-contract.md<br/>§2 = the authority registry"]
  end

  subgraph DISP["Dispatched work — precedence 3"]
    TASK["tasks/01-site-build-implement"]
    EPI["episodes/*"]
  end

  subgraph ENF["Mechanical enforcers"]
    V["tests/09-prompt-contract"]
    CORPUS["tests/10-prompt-validator"]
    BUDGET["scripts/context-budget"]
  end

  AGENTS --> C1
  AGENTS --> W2
  AGENTS --> C3
  AGENTS --> HT

  C1 -. "§2 registry" .-> W2
  C1 -.-> C3
  C1 -.-> UNIV
  C1 -.-> F1
  C1 -.-> CAP
  C1 -.-> HT
  C1 -.-> REC
  C1 -.-> TR
  C1 -.-> FEAT1
  C1 -.-> FEAT2

  W2 -. "§1 baseline load order" .-> C1
  W2 -.-> C3
  W2 -.-> UNIV
  W2 -.-> F1
  W2 -. "§3.1 worked example" .-> DOCS

  C3 -. "§4 naming" .-> F1
  C3 -. "§8 output/scope" .-> C1
  C3 -.-> UNIV
  UNIV -. "output §5 / DELTA §6 / untrusted §8" .-> C1
  UNIV -. "filename §3.1" .-> C3
  GLOSS -. "each term → its authoritative file" .-> C1
  HT -. "apply naming" .-> F1
  HT -. "authorization → contract §3" .-> C1

  FEAT2 -- "Dependencies" --> FEAT1
  TASK -- "TASK-FEATURES" --> FEAT1
  TASK -. "TASK-ACCEPTANCE → SITE-BUILD-R001/002/011" .-> FEAT1
  EPI -. "template + authoring rules" .-> HT

  V -. "resolves every prompt/... ref, one-home-per-rule" .-> C1
  V --> CORPUS
  BUDGET -. "enforces §1 baseline + budget" .-> W2
```

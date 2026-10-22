```mermaid
graph LR
  %% Core authority
  C01[01‑contract.md] -->|authoritative| C02[02‑workflow.md]
  C01 -->|authoritative| C03[03‑conventions.md]
  C01 -->|authoritative| COMMON[common/02‑universal‑rules.md]

  subgraph build
    MAKE -->|invoke| SCRIPTS
  end

  subgraph agents
    prompts --> OUT
  end

  subgraph tooling
    direction LR
    CHILD
    MAKE[Makefile]
    SCRIPTS[scripts/*.sh]
    TESTS[tests/*.sh]
    AIDER
  end

  subgraph prompts
    direction TB
    C01
    C02
    C03
    COMMON
    FLAVORS[flavors/]
    CAPABILITIES[capabilities/]
    FEATURES[features/]
    HOWTO[how‑to‑write‑*]
  end

  subgraph history
    direction TB
    EPISODES[episodes/]
    TASKS[tasks/]
    RECORDS[records/]
  end

  subgraph narrative
    DOCS[documents/]
  end

  subgraph products
    direction TB
    OUT[site.out/ & dataflow.out/ & logs/]
  end

  %% Feature ↔ Task linkage
  FEATURES -->|referenced by| TASKS[tasks/00‑tasks.md]
  FEATURES -->|referenced by| EPISODES
  CAPABILITIES -->|optional when| TASKS
  FLAVORS -->|optional when| TASKS

  %% Scripts & workflow
  SCRIPTS -->|executed by| C02
  MAKE -->|invokes| SCRIPTS
  TESTS -->|validated by| C02

  %% Generated artefacts (non‑re‑usable)
  OUT -.->|produced by| SCRIPTS
  OUT -.->|ignored by| C01

  %% Records & docs (templates)
  RECORDS -->|template for| CHILD[derived projects]
  DOCS -->|reference for| CHILD

  %% Tool‑specific config (history‑only)
  AIDER[.aider.*] -.->|local tooling| CHILD

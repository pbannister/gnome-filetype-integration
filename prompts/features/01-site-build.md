# Feature: Site Build

## Purpose

The project contains a static-site input directory (`site.in/`) and a generated static-site output directory (`site.out/`).

The Site Build feature provides the script that converts `site.in/` into `site.out/`.

## Requirements

- `SITE-BUILD-R001` — `scripts/site-build.sh` must generate the static site in `site.out/` from the input in `site.in/`.
- `SITE-BUILD-R002` — Each `site.in/*.txt` input file must produce `site.out/<name>.html`.
- `SITE-BUILD-R003` — Every non-`.txt`, non-`template.html` file under `site.in/` (authored assets such as scripts, styles, and images) must be copied verbatim into `site.out/`, so a page can reference it by relative path. `site.in/pages.nav` is input for the page set, not a published asset, and must not be copied.
- `SITE-BUILD-R004` — A page may contain `__KEY__` placeholders for live state; values come from the state file (`dataflow.out/site-state.txt` by default, overridable with `SITE_STATE_FILE`), written by `scripts/site-state-fetch.sh`. When the state file is absent, remaining placeholders render as `unavailable`, so the build stays portable.
- `SITE-BUILD-R005` — Generated pipeline artifacts the project publishes must be copied from `dataflow.out/` into `site.out/` when present, so the published tree is self-contained and does not depend on the pipeline output still existing on the serving host.
- `SITE-BUILD-R006` — A served asset that a page loads by URL must carry a content version. Derive one token from the contents of the interdependent asset set and append it to every URL in the module graph, including transitive imports; a cached asset must then be requested under a new URL when its bytes change. The build must fail when the stamp does not land, rather than publish an unversioned URL.
- `SITE-BUILD-R007` — Generated output must be identified as generated.
- `SITE-BUILD-R008` — The script must start from an empty output directory, so a renamed or
  removed page cannot linger in `site.out/` as a published orphan.
- `SITE-BUILD-R009` — The script must accept optional input and output directory arguments.
- `SITE-BUILD-R010` — When no arguments are given, the script must use `site.in/` and `site.out/` relative to the repository root.
- `SITE-BUILD-R011` — The script must be a POSIX shell script.
- `SITE-BUILD-R012` — The HTML page structure must live in `site.in/template.html`, not in the build script.
- `SITE-BUILD-R013` — `site.in/template.html` must contain the marker line `<!-- SITE-CONTENT -->` where page content is inserted.

## Behavior

- Running the script recreates `site.out/` from `site.in/` (pages and assets).
- Re-running the script overwrites existing output deterministically; a generated subtree copied into `site.out/` is replaced, not merged, so stale files cannot linger.

## Dependencies

- None.

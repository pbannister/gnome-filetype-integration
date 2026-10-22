#!/bin/sh
#
# skeleton-diff.sh: report how a derived project's shared files differ from
# this skeleton.
#
# A project derived from the skeleton keeps its own copy of the shared rule
# files, and those copies drift as the skeleton evolves. Run this from the
# skeleton against a project:
#
#     sh scripts/skeleton-diff.sh ~/work/<project>
#
# Files fall into three groups:
#
#   rules     Shared rule files; they must match this skeleton byte for byte.
#             A difference is drift and the script exits nonzero.
#   append    Shared documents a project extends with its own content (its
#             glossary terms, its document index, its episode index, the
#             project-pages summary). The skeleton's text must still be present
#             unchanged; additions are expected. Removing or rewording the
#             shared text is drift.
#   template  Reference scripts and the template, which a project adapts
#             (its own page title, extra assets). Differences are reported as
#             informational and do not fail.
#
# The append rule is the sanctioned customization pattern: append a project
# section, never fork the shared text. See prompts/03-conventions.md 5.
set -eu

DIRECTORY_SCRIPT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SKELETON_ROOT=$(CDPATH= cd -- "${2:-"$DIRECTORY_SCRIPT/.."}" && pwd)
PROJECT_ROOT=${1:-}

if [ -z "$PROJECT_ROOT" ]; then
    echo 'skeleton-diff: usage: skeleton-diff.sh PROJECT_DIR [SKELETON_DIR]' >&2
    exit 2
fi

if [ ! -d "$PROJECT_ROOT" ]; then
    echo "skeleton-diff: project directory not found: $PROJECT_ROOT" >&2
    exit 2
fi

FILES_RULES='
prompts/01-contract.md
prompts/02-workflow.md
prompts/03-conventions.md
prompts/README.md
prompts/common/02-universal-rules.md
prompts/flavors/01-semantic-sort-naming.md
prompts/flavors/02-cpp-conventions.md
prompts/capabilities/01-generated-documentation.md
prompts/capabilities/02-version-information.md
prompts/capabilities/03-generated-data-products.md
prompts/capabilities/04-release-and-publishing.md
prompts/capabilities/05-pinned-dependencies.md
prompts/capabilities/06-execution-boundary.md
prompts/capabilities/07-session-log.md
prompts/capabilities/08-delegation-authority.md
prompts/capabilities/09-failure-attribution.md
prompts/how-to-write-tasks.md
prompts/how-to-write-features.md
prompts/how-to-write-episodes.md
prompts/how-to-write-research.md
prompts/episodes/01-episode-template.md
prompts/episodes/02-episode-plan.md
prompts/features/02-project-pages.md
records/README.md
tests/README.md
'

FILES_APPEND='
AGENTS.md
evals/README.md
prompts/common/03-glossary.md
prompts/episodes/00-episodes.md
documents/README.md
documents/06-project-pages.md
documents/07-prompt-maturity.md
'

FILES_TEMPLATE='
scripts/site-build.sh
scripts/site-condense.sh
scripts/tests-run.sh
scripts/release-package.sh
scripts/install.sh
scripts/status.sh
scripts/prompt-maturity.sh
scripts/context-budget.sh
tests/00-skeleton.sh
tests/09-prompt-contract.sh
tests/10-prompt-validator.sh
tests/11-release-install.sh
tests/12-status.sh
tests/13-corpus-coverage.sh
tests/14-context-budget.sh
site.in/template.html
'

count_drift=0
count_missing=0
count_append=0
count_template=0

report_rules() {
    for rel in $FILES_RULES; do
        file_skeleton="$SKELETON_ROOT/$rel"
        file_project="$PROJECT_ROOT/$rel"
        if [ ! -f "$file_project" ]; then
            echo "skeleton-diff: missing in project: $rel"
            count_missing=$((count_missing + 1))
            continue
        fi
        if [ ! -f "$file_skeleton" ]; then
            echo "skeleton-diff: not in this skeleton: $rel"
            continue
        fi
        if ! diff -q "$file_skeleton" "$file_project" >/dev/null 2>&1; then
            echo "skeleton-diff: drift: $rel"
            count_drift=$((count_drift + 1))
        fi
    done
}

report_append() {
    for rel in $FILES_APPEND; do
        file_skeleton="$SKELETON_ROOT/$rel"
        file_project="$PROJECT_ROOT/$rel"
        if [ ! -f "$file_project" ]; then
            echo "skeleton-diff: missing in project: $rel"
            count_missing=$((count_missing + 1))
            continue
        fi
        if [ ! -f "$file_skeleton" ]; then
            echo "skeleton-diff: not in this skeleton: $rel"
            continue
        fi
        if diff -q "$file_skeleton" "$file_project" >/dev/null 2>&1; then
            continue
        fi
        # Append-only means the project's file begins with the skeleton's
        # exact text and only adds below it, so a prepended, deleted, or
        # reworded shared line is still drift.
        lines_skeleton=$(wc -l < "$file_skeleton" | tr -d ' ')
        if head -n "$lines_skeleton" "$file_project" | diff -q "$file_skeleton" - >/dev/null 2>&1; then
            echo "skeleton-diff: appended (ok): $rel"
            count_append=$((count_append + 1))
        else
            echo "skeleton-diff: drift (shared text changed or removed): $rel"
            count_drift=$((count_drift + 1))
        fi
    done
}

report_template() {
    for rel in $FILES_TEMPLATE; do
        file_skeleton="$SKELETON_ROOT/$rel"
        file_project="$PROJECT_ROOT/$rel"
        if [ ! -f "$file_project" ] || [ ! -f "$file_skeleton" ]; then
            continue
        fi
        if ! diff -q "$file_skeleton" "$file_project" >/dev/null 2>&1; then
            echo "skeleton-diff: adapted (informational): $rel"
            count_template=$((count_template + 1))
        fi
    done
}

report_rules
report_append
report_template

echo "skeleton-diff: $count_drift drift, $count_missing missing, $count_append appended, $count_template reference artifact(s) adapted"

if [ "$count_drift" -ne 0 ] || [ "$count_missing" -ne 0 ]; then
    echo 'skeleton-diff: shared rule files differ; update them, and append a project section instead of forking shared text (conventions 5).' >&2
    exit 1
fi

exit 0

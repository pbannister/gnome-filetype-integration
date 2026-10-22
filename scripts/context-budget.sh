#!/bin/sh
#
# context-budget.sh: measure the always-loaded context and enforce the budget.
#
# The always-loaded context is the entry point plus the mandatory baseline that
# prompts/02-workflow.md section 1 lists. That section declares the budget too,
# so the load list and its size limit have one home.
#
# Read-only, and it never blocks on standard input
# (prompts/03-conventions.md section 7.1).
#
# Usage: context-budget.sh [PROJECT_DIR]
set -eu

DIRECTORY_SCRIPT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "${1:-"$DIRECTORY_SCRIPT/.."}" && pwd)

FILE_WORKFLOW="$PROJECT_ROOT/prompts/02-workflow.md"

if [ ! -f "$FILE_WORKFLOW" ]; then
    echo "context-budget: missing prompts/02-workflow.md under: $PROJECT_ROOT" >&2
    exit 2
fi

budget=$(sed -n 's/^Always-loaded context budget:[[:space:]]*\([0-9][0-9]*\) bytes.*$/\1/p' \
    "$FILE_WORKFLOW" | head -n 1)
if [ -z "$budget" ]; then
    echo 'context-budget: prompts/02-workflow.md declares no "Always-loaded context budget: <N> bytes" line' >&2
    exit 2
fi
# Normalize a zero-padded declaration, so a fixed-width number is not read as octal.
budget=$(printf '%s' "$budget" | sed 's/^0*//')
budget=${budget:-0}

files=$(sed -n '/^Always load the mandatory baseline/,/^After the baseline/p' "$FILE_WORKFLOW" \
    | sed -n 's/^- `\(prompts\/[^`]*\)`$/\1/p')
if [ -z "$files" ]; then
    echo 'context-budget: section 1 lists no baseline files' >&2
    exit 2
fi

total=0
count=0
largest_name='none'
largest_size=0
for rel in $files; do
    if [ ! -f "$PROJECT_ROOT/$rel" ]; then
        echo "context-budget: baseline file is missing: $rel" >&2
        exit 2
    fi
    size=$(wc -c < "$PROJECT_ROOT/$rel" | tr -d ' ')
    total=$((total + size))
    count=$((count + 1))
    if [ "$size" -gt "$largest_size" ]; then
        largest_size=$size
        largest_name=$rel
    fi
    printf '  %7d  %s\n' "$size" "$rel"
done

# The entry point is always loaded when the project has one.
if [ -f "$PROJECT_ROOT/AGENTS.md" ]; then
    size=$(wc -c < "$PROJECT_ROOT/AGENTS.md" | tr -d ' ')
    total=$((total + size))
    printf '  %7d  %s\n' "$size" 'AGENTS.md'
fi

if [ "$total" -gt "$budget" ]; then
    echo "context-budget: $total bytes exceeds the declared budget of $budget bytes" >&2
    echo "context-budget: the largest contributor is $largest_name at $largest_size bytes" >&2
    echo 'context-budget: move a conditional rule out of the baseline, or raise the declared budget deliberately' >&2
    exit 1
fi

printf 'context-budget: ok (%s/%s bytes, %s baseline files plus the entry point)\n' \
    "$total" "$budget" "$count"
exit 0

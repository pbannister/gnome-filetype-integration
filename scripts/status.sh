#!/bin/sh
#
# status.sh: one-screen orientation for a fresh session.
#
# Prints the next open TODO item, the last recorded test result, and the
# working-tree state. Read-only, and it never blocks on
# standard input (prompts/03-conventions.md section 7.1).
#
# Usage: status.sh [PROJECT_DIR]
set -eu

DIRECTORY_SCRIPT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "${1:-"$DIRECTORY_SCRIPT/.."}" && pwd)

echo "== project: $PROJECT_ROOT"

if [ -f "$PROJECT_ROOT/TODO.md" ]; then
    item_next=$(grep -m1 '^\* \[ \]' "$PROJECT_ROOT/TODO.md" || true)
    echo "== next TODO: ${item_next:-none open}"
else
    echo "== next TODO: TODO.md missing"
fi

if [ -d "$PROJECT_ROOT/logs" ]; then
    file_log=$(ls -1 "$PROJECT_ROOT"/logs/[0-9]*test-run.log 2>/dev/null | sort | tail -n 1 || true)
else
    file_log=''
fi
if [ -n "$file_log" ]; then
    count_fail=$(grep -c '^FAIL' "$file_log" 2>/dev/null || true)
    echo "== last test run: $(basename "$file_log") — ${count_fail:-0} failure(s)"
    tail -n 1 "$file_log" | sed 's/^/   /'
else
    echo "== last test run: none recorded"
fi

if git -C "$PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    branch_name=$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')
    echo "== git: branch $branch_name"
    changes_tree=$(git -C "$PROJECT_ROOT" status --short 2>/dev/null || true)
    if [ -n "$changes_tree" ]; then
        echo "== working tree: uncommitted changes"
        printf '%s\n' "$changes_tree" | sed 's/^/   /'
    else
        echo "== working tree: clean"
    fi
    git -C "$PROJECT_ROOT" log -1 --oneline 2>/dev/null | sed 's/^/   /' || true
else
    echo "== git: not a repository"
fi

exit 0

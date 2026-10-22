#!/bin/sh
#
# Context-budget test: the always-loaded context stays inside its declared
# budget.
#
# Tier: portable. Builds a scratch project with known file sizes, so the
# assertions do not depend on how large this repository happens to be.
set -eu

DIRECTORY_SCRIPT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$DIRECTORY_SCRIPT/.." && pwd)
SCRIPT_BUDGET="$REPOSITORY_ROOT/scripts/context-budget.sh"

. "$DIRECTORY_SCRIPT/lib/test_helpers.sh"

DIRECTORY_TEST=$(mktemp -d)
trap 'rm -rf "$DIRECTORY_TEST"' EXIT HUP INT TERM
DIRECTORY_ROOT="$DIRECTORY_TEST/root"

fail() {
    echo "14-context-budget: $1" >&2
    exit 1
}

# make_file <path> <bytes>: a file of exactly the requested size.
make_file() {
    mkdir -p "$(dirname "$1")"
    head -c "$2" /dev/zero | tr '\0' 'x' > "$1"
}

FILE_WORKFLOW="$DIRECTORY_ROOT/prompts/02-workflow.md"
make_file "$DIRECTORY_ROOT/prompts/01-contract.md" 100
make_file "$DIRECTORY_ROOT/AGENTS.md" 20

# The budget is a fixed-width placeholder, so substituting a real number does
# not change the size of the workflow file the script measures.
write_workflow() {
    mkdir -p "$DIRECTORY_ROOT/prompts"
    cat > "$FILE_WORKFLOW" <<'EOF'
# LLM Workflow

## 1. Load Project Rules

Always load the mandatory baseline in this order before executing a task:

- `prompts/01-contract.md`
- `prompts/02-workflow.md`

Always-loaded context budget: 000400 bytes — the entry point plus this baseline.

After the baseline, load only the task-relevant files:

- Load no other prompt files.
EOF
}

set_budget() {
    sed -i "s/000400/$(printf '%06d' "$1")/" "$FILE_WORKFLOW"
}

write_workflow
total=$(cat "$FILE_WORKFLOW" "$DIRECTORY_ROOT/prompts/01-contract.md" \
    "$DIRECTORY_ROOT/AGENTS.md" | wc -c | tr -d ' ')

# 1. A budget with headroom passes.
write_workflow; set_budget $((total + 10))
output_budget=$(sh "$SCRIPT_BUDGET" "$DIRECTORY_ROOT" </dev/null) \
    || fail "a budget with headroom was refused: $output_budget"
printf '%s\n' "$output_budget" | grep -qF "ok ($total/$((total + 10)) bytes" \
    || fail "the measured total is wrong: $output_budget"
printf '%s\n' "$output_budget" | grep -qF '2 baseline files plus the entry point' \
    || fail "the file count is wrong: $output_budget"

# 2. Exceeding the budget fails, and names the largest contributor.
write_workflow; set_budget $((total - 10))
if output_budget=$(sh "$SCRIPT_BUDGET" "$DIRECTORY_ROOT" 2>&1 </dev/null); then
    fail 'a budget below the measured total was accepted'
fi
printf '%s\n' "$output_budget" | grep -qF 'exceeds the declared budget' \
    || fail "the refusal is not explained: $output_budget"
printf '%s\n' "$output_budget" | grep -qF 'largest contributor' \
    || fail "the refusal does not name the largest contributor: $output_budget"

# 3. A missing budget line fails loudly.
write_workflow; sed -i '/^Always-loaded context budget:/d' "$FILE_WORKFLOW"
if output_budget=$(sh "$SCRIPT_BUDGET" "$DIRECTORY_ROOT" 2>&1 </dev/null); then
    fail 'a project without a declared budget was accepted'
fi
printf '%s\n' "$output_budget" | grep -qF 'declares no' \
    || fail "the missing budget is not reported: $output_budget"

# 4. A missing baseline file fails loudly.
write_workflow; rm "$DIRECTORY_ROOT/prompts/01-contract.md"
if output_budget=$(sh "$SCRIPT_BUDGET" "$DIRECTORY_ROOT" 2>&1 </dev/null); then
    fail 'a missing baseline file was accepted'
fi
printf '%s\n' "$output_budget" | grep -qF 'baseline file is missing' \
    || fail "the missing file is not reported: $output_budget"

# 5. This repository is inside its own declared budget.
output_budget=$(cd "$REPOSITORY_ROOT" && sh "$SCRIPT_BUDGET" </dev/null)
printf '%s\n' "$output_budget" | grep -qF 'context-budget: ok' \
    || fail "this repository is over budget: $output_budget"

echo '14-context-budget: ok'
exit 0

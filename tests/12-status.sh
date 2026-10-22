#!/bin/sh
#
# Status test: scripts/status.sh orients a fresh session.
#
# Tier: portable. Builds a scratch project, so the assertions do not depend on
# this repository's live state.
set -eu

DIRECTORY_SCRIPT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$DIRECTORY_SCRIPT/.." && pwd)
SCRIPT_STATUS="$REPOSITORY_ROOT/scripts/status.sh"

. "$DIRECTORY_SCRIPT/lib/test_helpers.sh"

DIRECTORY_TEST=$(mktemp -d)
trap 'rm -rf "$DIRECTORY_TEST"' EXIT HUP INT TERM
DIRECTORY_ROOT="$DIRECTORY_TEST/root"
mkdir -p "$DIRECTORY_ROOT/logs"

fail() {
    echo "12-status: $1" >&2
    exit 1
}

cat > "$DIRECTORY_ROOT/TODO.md" <<'EOF'
# TODO

## Open Questions

* [ ] decide the next episode.

## Recently Completed

* [x] something.
EOF

# 1. A scratch project without logs or git still orients and exits zero.
output_status=$(cd "$DIRECTORY_ROOT" && sh "$SCRIPT_STATUS" "$DIRECTORY_ROOT" </dev/null)
printf '%s\n' "$output_status" | grep -qF 'decide the next episode' \
    || fail "the next TODO item is missing: $output_status"
printf '%s\n' "$output_status" | grep -qF 'none recorded' \
    || fail "an empty log directory was not reported: $output_status"

# 2. A recorded failure is reported with its count.
cat > "$DIRECTORY_ROOT/logs/2026-01-02-03-04-05-test-run.log" <<'EOF'
PASS 00-skeleton.sh
FAIL 01-site-build.sh
tests-run: 1 test failed
EOF
output_status=$(sh "$SCRIPT_STATUS" "$DIRECTORY_ROOT" </dev/null)
printf '%s\n' "$output_status" | grep -qF '1 failure(s)' \
    || fail "the failure count is missing: $output_status"
printf '%s\n' "$output_status" | grep -qF 'tests-run: 1 test failed' \
    || fail "the last result line is missing: $output_status"

# 3. A clean repository reports its branch and a clean tree.
if command -v git >/dev/null 2>&1; then
    git -C "$DIRECTORY_ROOT" init -q
    git -C "$DIRECTORY_ROOT" -c user.name=test -c user.email=test@example.invalid \
        add -A
    git -C "$DIRECTORY_ROOT" -c user.name=test -c user.email=test@example.invalid \
        commit -q -m 'test: baseline'
    output_status=$(sh "$SCRIPT_STATUS" "$DIRECTORY_ROOT" </dev/null)
    printf '%s\n' "$output_status" | grep -qF 'working tree: clean' \
        || fail "a clean tree was not reported: $output_status"
fi

# 4. This repository orients.
output_status=$(cd "$REPOSITORY_ROOT" && sh "$SCRIPT_STATUS" </dev/null)
printf '%s\n' "$output_status" | grep -qF '== project:' \
    || fail "this repository did not report its project path: $output_status"

echo '12-status: ok'
exit 0

#!/bin/sh
#
# Release-gate test (scripts/release-gate.sh).
#
# Tier: tool-gated (git). Runs the gate in a throwaway git repository:
#
#   * a clean tree with a version naming HEAD passes;
#   * a -changes version is refused;
#   * a version that does not name HEAD is refused;
#   * a dirty tree is refused even with a correct version.
set -eu

DIRECTORY_SCRIPT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$DIRECTORY_SCRIPT/.." && pwd)

. "$DIRECTORY_SCRIPT/lib/test_helpers.sh"
skip_unless_tool git

DIRECTORY_TEST=$(mktemp -d)
trap 'rm -rf "$DIRECTORY_TEST"' EXIT HUP INT TERM

fail() {
    echo "07-release-gate: $1" >&2
    exit 1
}

mkdir -p "$DIRECTORY_TEST/scripts"
cp "$REPOSITORY_ROOT/scripts/release-gate.sh" "$DIRECTORY_TEST/scripts/release-gate.sh"

cd "$DIRECTORY_TEST"
git init -q
git config user.email test@example.invalid
git config user.name test
git add scripts/release-gate.sh
git commit -q -m 'initial'

BRANCH_TEST=$(git rev-parse --abbrev-ref HEAD)
HASH_TEST=$(git rev-parse --short HEAD)
VERSION_GOOD="2026-09-24-${BRANCH_TEST}-${HASH_TEST}"

sh scripts/release-gate.sh "$VERSION_GOOD" >/dev/null \
    || fail 'a clean tree with a matching version was refused'

if sh scripts/release-gate.sh "$VERSION_GOOD-changes" >/dev/null 2>&1; then
    fail 'a -changes version was accepted'
fi

if sh scripts/release-gate.sh "2026-09-24-${BRANCH_TEST}-deadbeef" >/dev/null 2>&1; then
    fail 'a version that does not name HEAD was accepted'
fi

printf '%s\n' 'dirty' > uncommitted.txt
if sh scripts/release-gate.sh "$VERSION_GOOD" >/dev/null 2>&1; then
    fail 'a dirty tree was accepted'
fi

echo '07-release-gate: ok'
exit 0

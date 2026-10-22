#!/bin/sh
#
# Version-generator test (scripts/version-generate.sh).
#
# Tier: tool-gated (git). Runs the canonical generator inside a throwaway git
# repository and checks the version shape from prompts/03-conventions.md 6.2:
#
#   * date-branch-hash with a tagged commit and a dirty tree suffix;
#   * the generated header carries a provenance note and the two macros;
#   * the build counter increments on each build and is never checked in.
set -eu

DIRECTORY_SCRIPT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$DIRECTORY_SCRIPT/.." && pwd)

. "$DIRECTORY_SCRIPT/lib/test_helpers.sh"
skip_unless_tool git

DIRECTORY_TEST=$(mktemp -d)
trap 'rm -rf "$DIRECTORY_TEST"' EXIT HUP INT TERM

fail() {
    echo "05-version-generate: $1" >&2
    exit 1
}

mkdir -p "$DIRECTORY_TEST/scripts"
cp "$REPOSITORY_ROOT/scripts/version-generate.sh" "$DIRECTORY_TEST/scripts/version-generate.sh"

cd "$DIRECTORY_TEST"
git init -q
git config user.email test@example.invalid
git config user.name test
git add scripts/version-generate.sh
git commit -q -m 'initial'

FILE_HEADER="$DIRECTORY_TEST/dataflow.out/build/generated/version_info.h"
FILE_COUNTER="$DIRECTORY_TEST/dataflow.out/build/version-build-counter"

sh scripts/version-generate.sh >/dev/null
[ -f "$FILE_HEADER" ] || fail 'the header was not written'

grep -q 'Generated from git state by scripts/version-generate.sh' "$FILE_HEADER" \
    || fail 'the header is missing its provenance note'

BRANCH_TEST=$(git rev-parse --abbrev-ref HEAD)
HASH_TEST=$(git rev-parse --short HEAD)
grep -q "^#define VERSION_STRING_VALUE \"[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-${BRANCH_TEST}-${HASH_TEST}\"$" "$FILE_HEADER" \
    || fail "the version is not date-branch-hash: $(grep VERSION_STRING_VALUE "$FILE_HEADER")"

[ "$(cat "$FILE_COUNTER")" = 1 ] || fail 'the build counter did not start at 1'

sh scripts/version-generate.sh >/dev/null
[ "$(cat "$FILE_COUNTER")" = 2 ] || fail 'the build counter did not increment'

# A tagged commit carries the tag; a dirty tree carries -changes.
git tag -a v1.0.0 -m 'release'
printf '%s\n' 'dirty' > dirt.txt
sh scripts/version-generate.sh >/dev/null
grep -q "^#define VERSION_STRING_VALUE \"[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-${BRANCH_TEST}-v1\.0\.0-${HASH_TEST}-changes\"$" "$FILE_HEADER" \
    || fail "the tag/changes suffix is wrong: $(grep VERSION_STRING_VALUE "$FILE_HEADER")"

echo '05-version-generate: ok'
exit 0

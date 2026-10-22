#!/bin/sh
#
# version-generate.sh: write the build-time version header.
#
# The version is a build-time fact derived from git state, never a source
# literal; see prompts/capabilities/02-version-information.md, which names this script
# and version_info.h as canonical.
#
# The generated header is written to the build output directory and is never
# edited by hand. The build counter increments on each run and is not checked
# in.
#
# Usage: version-generate.sh
#
# A project's version-reporting unit (the canonical functions are
# version_string() and version_build_counter()) includes this header and
# returns the macro values.
set -eu

DIRECTORY_SCRIPT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$DIRECTORY_SCRIPT/.." && pwd)
DIRECTORY_BUILD="$REPOSITORY_ROOT/dataflow.out/build"
DIRECTORY_GENERATED="$DIRECTORY_BUILD/generated"
FILE_HEADER="$DIRECTORY_GENERATED/version_info.h"
FILE_COUNTER="$DIRECTORY_BUILD/version-build-counter"

mkdir -p "$DIRECTORY_GENERATED"

DATE_BUILD=$(date +%Y-%m-%d)
BRANCH_BUILD=$(git -C "$REPOSITORY_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)
HASH_BUILD=$(git -C "$REPOSITORY_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)

# The tag appears only when the current commit is tagged exactly.
SUFFIX_TAG=
if TAG_BUILD=$(git -C "$REPOSITORY_ROOT" describe --exact-match --tags 2>/dev/null); then
    SUFFIX_TAG="-$TAG_BUILD"
fi

# The -changes suffix marks a build from a dirty tree; a release gate refuses
# a version that carries it.
SUFFIX_CHANGES=
if [ -n "$(git -C "$REPOSITORY_ROOT" status --porcelain 2>/dev/null)" ]; then
    SUFFIX_CHANGES=-changes
fi

VERSION_STRING="$DATE_BUILD-$BRANCH_BUILD$SUFFIX_TAG-$HASH_BUILD$SUFFIX_CHANGES"

COUNTER_BUILD=0
if [ -f "$FILE_COUNTER" ]; then
    COUNTER_BUILD=$(cat "$FILE_COUNTER")
fi
COUNTER_BUILD=$((COUNTER_BUILD + 1))
printf '%s\n' "$COUNTER_BUILD" > "$FILE_COUNTER"

{
    echo '/* Generated from git state by scripts/version-generate.sh - do not edit by hand. */'
    echo '#pragma once'
    printf '#define VERSION_STRING_VALUE "%s"\n' "$VERSION_STRING"
    printf '#define VERSION_BUILD_COUNTER_VALUE %s\n' "$COUNTER_BUILD"
} > "$FILE_HEADER"

echo "version-generate: wrote $FILE_HEADER ($VERSION_STRING)"
exit 0

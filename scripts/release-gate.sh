#!/bin/sh
#
# release-gate.sh: refuse to publish a build that is not the current commit's.
#
# An artifact may only be released as the commit it actually came from. The
# project builds the program first and passes the version the program reports
# (see prompts/03-conventions.md 6.2 and 6.4).
#
# Usage: release-gate.sh VERSION
#
# The gate refuses unless:
#   * the working tree is clean (no uncommitted changes);
#   * the version does not carry the -changes suffix (a dirty-tree build);
#   * the version names the current short commit hash.
set -eu

DIRECTORY_SCRIPT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$DIRECTORY_SCRIPT/.." && pwd)

refuse() {
    echo "release-gate: refusing: $1" >&2
    exit 1
}

if [ "$#" -ne 1 ]; then
    echo 'release-gate: usage: release-gate.sh VERSION' >&2
    exit 2
fi

VERSION_RELEASE=$1
COMMIT_RELEASE=$(git -C "$REPOSITORY_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)

if [ "unknown" = "$COMMIT_RELEASE" ]; then
    refuse 'the repository is not a git checkout'
fi

if [ -n "$(git -C "$REPOSITORY_ROOT" status --porcelain 2>/dev/null)" ]; then
    refuse 'the working tree has changes; commit them first'
fi

case "$VERSION_RELEASE" in
    *-changes)
        refuse "the products were built from a dirty tree ($VERSION_RELEASE)"
        ;;
esac

case "$VERSION_RELEASE" in
    *"$COMMIT_RELEASE"*)
        ;;
    *)
        refuse "the build reports $VERSION_RELEASE, which does not name $COMMIT_RELEASE"
        ;;
esac

echo "release-gate: ok: $VERSION_RELEASE names $COMMIT_RELEASE"
exit 0

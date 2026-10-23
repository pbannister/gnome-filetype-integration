#!/bin/sh
#
# release-publish.sh: tag the current commit and publish the packaged files as a
# GitHub release.
#
# Run it from a clean tree, after the work is committed:
#
#   TAG=v0.2.0 make release-publish
#
# It builds from the commit being released, so the products in the tarball are
# that commit's. It refuses a dirty tree, a version that does not name the
# commit, and a tag that is on another commit; it reuses a tag already on the
# commit, skips a redundant push, and re-uploads the assets when the release
# already exists (prompts/capabilities/04-release-and-publishing.md).
#
# Environment:
#   TAG          the release tag (default: the tag on this commit, else
#                v<date>-<branch>)
#   TITLE        the release title (default "<date> — GNOME File Type
#                Integration (<branch>-<commit>)")
#   PUSH_REMOTE  where to push the commit and the tag (default origin)
set -eu

DIRECTORY_SCRIPT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$DIRECTORY_SCRIPT/.." && pwd)
DIRECTORY_BUILD="$REPOSITORY_ROOT/dataflow.out/build"
DIRECTORY_RELEASE="$REPOSITORY_ROOT/dataflow.out/release"
PUSH_REMOTE=${PUSH_REMOTE:-origin}

if ! command -v gh > /dev/null 2>&1; then
    echo "release-publish: the GitHub CLI (gh) is needed; see https://cli.github.com" >&2
    exit 1
fi
if ! gh auth status > /dev/null 2>&1; then
    echo "release-publish: gh is not authenticated; run 'gh auth login', or set GH_TOKEN" >&2
    exit 1
fi

if [ -n "$(git -C "$REPOSITORY_ROOT" status --porcelain)" ]; then
    echo "release-publish: the working tree has changes; commit them first" >&2
    exit 1
fi

if ! git -C "$REPOSITORY_ROOT" remote get-url "$PUSH_REMOTE" > /dev/null 2>&1; then
    echo "release-publish: no '$PUSH_REMOTE' remote; create the repository and add it first" >&2
    echo "release-publish:   gh repo create pbannister/gnome-filetype-integration --public --source . --remote origin --push" >&2
    exit 1
fi

# Build from the commit being released, so a stale build tree cannot be
# published.
sh "$DIRECTORY_SCRIPT/program-build.sh"

VERSION=$("$DIRECTORY_BUILD/program/bin/filetype" --version | awk '{print $2}')
export VERSION
sh "$DIRECTORY_SCRIPT/release-gate.sh" "$VERSION"

sh "$DIRECTORY_SCRIPT/release-package.sh"

VERSION=$(cat "$DIRECTORY_RELEASE/VERSION")
# Without TAG, publish the tag this commit already carries, and only generate
# one when the commit has none: a release should reuse the tag a person chose.
# A generated tag names the release by date and branch: v<date>-<branch>.
if [ -z "${TAG:-}" ]; then
    TAG=$(git -C "$REPOSITORY_ROOT" tag --points-at HEAD | head -1)
fi
if [ -z "${TAG:-}" ]; then
    branch_for_tag=$(git -C "$REPOSITORY_ROOT" symbolic-ref --short HEAD 2>/dev/null || true)
    if [ -z "$branch_for_tag" ]; then
        echo "release-publish: the checkout is not on a branch; set TAG explicitly" >&2
        exit 1
    fi
    TAG="v$(date +%F)-$branch_for_tag"
fi
# GitHub's release list is narrow, so the title leads with the date, then the
# project name; the branch and commit follow and may be truncated.
RELEASE_DATE=$(printf '%s' "$VERSION" | cut -c1-10)
RELEASE_DETAIL=$(printf '%s' "$VERSION" | cut -c12-)
TITLE=${TITLE:-"$RELEASE_DATE — GNOME File Type Integration ($RELEASE_DETAIL)"}
FILE_TARBALL=$(find "$DIRECTORY_RELEASE" -maxdepth 1 -name '*.tar.gz' | head -1)
if [ -z "$FILE_TARBALL" ]; then
    echo "release-publish: release-package.sh produced no tarball" >&2
    exit 1
fi
if [ ! -f "$DIRECTORY_RELEASE/SHA256SUMS" ]; then
    echo "release-publish: release-package.sh produced no SHA256SUMS" >&2
    exit 1
fi

HEAD_COMMIT=$(git -C "$REPOSITORY_ROOT" rev-parse HEAD)
if git -C "$REPOSITORY_ROOT" rev-parse --verify --quiet "refs/tags/$TAG" > /dev/null; then
    TAG_COMMIT=$(git -C "$REPOSITORY_ROOT" rev-parse "$TAG^{commit}")
    if [ "$TAG_COMMIT" != "$HEAD_COMMIT" ]; then
        echo "release-publish: tag $TAG is on $TAG_COMMIT, not on $HEAD_COMMIT" >&2
        echo "release-publish: a release has to match its tag; move the tag, or set TAG" >&2
        exit 1
    fi
    echo "release-publish: tag $TAG already exists on this commit; publishing the files to it"
else
    git -C "$REPOSITORY_ROOT" tag -a "$TAG" -m "$TITLE"
    echo "release-publish: tagged $TAG"
fi

# The commit and the tag first: a release whose tag is not pushed cannot be
# fetched. The remote having a ref is not the same as the remote having *this*
# commit, so the two are compared.
push_if_needed() { # <ref> <description>
    ref_local=$(git -C "$REPOSITORY_ROOT" rev-parse "$1")
    ref_remote=$(git -C "$REPOSITORY_ROOT" ls-remote --refs "$PUSH_REMOTE" "$1" 2>/dev/null \
        | awk '{print $1}' | head -1)
    if [ "$ref_local" = "$ref_remote" ]; then
        echo "release-publish: $PUSH_REMOTE already has $2"
        return 0
    fi
    if ! git -C "$REPOSITORY_ROOT" push "$PUSH_REMOTE" "$1"; then
        echo "release-publish: could not push $2 to $PUSH_REMOTE" >&2
        echo "release-publish: if this checkout pushes over SSH, set PUSH_REMOTE" >&2
        return 1
    fi
    echo "release-publish: pushed $2"
    return 0
}

BRANCH=$(git -C "$REPOSITORY_ROOT" symbolic-ref --short HEAD)
push_if_needed "refs/heads/$BRANCH" "the branch $BRANCH" || exit 1
push_if_needed "refs/tags/$TAG" "the tag $TAG" || exit 1

if gh release view "$TAG" > /dev/null 2>&1; then
    echo "release-publish: release $TAG exists; uploading the files to it"
    gh release upload "$TAG" "$FILE_TARBALL" "$DIRECTORY_RELEASE/SHA256SUMS" --clobber
else
    gh release create "$TAG" \
        --title "$TITLE" \
        --notes-file "$DIRECTORY_RELEASE/RELEASE-NOTES.md" \
        "$FILE_TARBALL" "$DIRECTORY_RELEASE/SHA256SUMS"
fi

echo "release-publish: $TAG is published"
repository_url=$(git -C "$REPOSITORY_ROOT" remote get-url "$PUSH_REMOTE")
case "$repository_url" in
    https://github.com/*)
        repository_slug=${repository_url#https://github.com/}
        repository_slug=${repository_slug%.git}
        echo "release-publish: https://github.com/$repository_slug/releases/tag/$TAG"
        ;;
    git@github.com:*)
        repository_slug=${repository_url#git@github.com:}
        repository_slug=${repository_slug%.git}
        echo "release-publish: https://github.com/$repository_slug/releases/tag/$TAG"
        ;;
esac

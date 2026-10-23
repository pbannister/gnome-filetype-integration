#!/bin/sh
#
# Release-publish test (prompts/capabilities/04-release-and-publishing.md).
#
# Tier: tool-gated (git).  Builds a scratch repository with a local bare remote
# and a stub `gh`, so the real release-publish.sh is exercised end to end
# without contacting GitHub:
#
#   * a clean publish tags the commit, pushes the branch and the tag, and
#     creates the release with the tarball and its checksum;
#   * a second publish reuses the tag and re-uploads the assets;
#   * a dirty tree is refused;
#   * a tag on another commit is refused;
#   * a missing remote is refused with the repository-creation command.
set -eu

DIRECTORY_SCRIPT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$DIRECTORY_SCRIPT/.." && pwd)
. "$DIRECTORY_SCRIPT/lib/test_helpers.sh"

NAME_TEST=$(basename "$0" .sh)
skip_unless_tool git

DIRECTORY_TEST=$(mktemp -d)
trap 'rm -rf "$DIRECTORY_TEST"' EXIT HUP INT TERM

DIRECTORY_ROOT="$DIRECTORY_TEST/project"
DIRECTORY_REMOTE="$DIRECTORY_TEST/remote.git"
DIRECTORY_BIN="$DIRECTORY_TEST/bin"
FILE_LOG="$DIRECTORY_TEST/gh.log"

fail() {
    fail_test "$NAME_TEST" "$1"
}

mkdir -p "$DIRECTORY_ROOT/scripts" "$DIRECTORY_BIN"
cp "$REPOSITORY_ROOT/scripts/release-publish.sh" "$DIRECTORY_ROOT/scripts/release-publish.sh"
cp "$REPOSITORY_ROOT/scripts/release-gate.sh" "$DIRECTORY_ROOT/scripts/release-gate.sh"

# The build and package steps are replaced: this test is about the publish
# decisions, not the Python package.  The fake build reports the current short
# commit, which is what the real build would report.
cat > "$DIRECTORY_ROOT/scripts/program-build.sh" <<'BUILD'
#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$root/dataflow.out/build/program/bin"
hash=$(git -C "$root" rev-parse --short HEAD)
version="2026-01-01-test-$hash"
cat > "$root/dataflow.out/build/program/bin/filetype" <<PROGRAM
#!/bin/sh
echo "filetype $version (build 1)"
PROGRAM
chmod +x "$root/dataflow.out/build/program/bin/filetype"
BUILD

cat > "$DIRECTORY_ROOT/scripts/release-package.sh" <<'PACKAGE'
#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if [ ! -x "$root/dataflow.out/build/program/bin/filetype" ]; then
    echo "release-package: the build tree was not staged" >&2
    exit 1
fi
mkdir -p "$root/dataflow.out/release"
printf '%s\n' "${VERSION:-missing}" > "$root/dataflow.out/release/VERSION"
printf 'fake tarball\n' > "$root/dataflow.out/release/gnome-filetype-integration-linux-x86_64.tar.gz"
printf 'fake checksum\n' > "$root/dataflow.out/release/SHA256SUMS"
printf '# fake release notes\n' > "$root/dataflow.out/release/RELEASE-NOTES.md"
PACKAGE

cat > "$DIRECTORY_BIN/gh" <<'GH'
#!/bin/sh
printf '%s\n' "$*" >> "${GH_LOG:?}"
case "$1 $2" in
    "auth status")
        exit 0
        ;;
    "release view")
        [ "${GH_RELEASE_EXISTS:-0}" = 1 ] && exit 0
        exit 1
        ;;
    "release create" | "release upload")
        exit 0
        ;;
esac
exit 0
GH
chmod +x "$DIRECTORY_BIN/gh" "$DIRECTORY_ROOT/scripts/program-build.sh" \
    "$DIRECTORY_ROOT/scripts/release-package.sh"

printf 'dataflow.out/*\n' > "$DIRECTORY_ROOT/.gitignore"
printf 'tracked\n' > "$DIRECTORY_ROOT/tracked.txt"
git init -q "$DIRECTORY_ROOT"
git -C "$DIRECTORY_ROOT" config user.name test
git -C "$DIRECTORY_ROOT" config user.email test@example.invalid
git init --bare -q "$DIRECTORY_REMOTE"
git -C "$DIRECTORY_ROOT" remote add origin "$DIRECTORY_REMOTE"
git -C "$DIRECTORY_ROOT" add -A
git -C "$DIRECTORY_ROOT" commit -q -m 'test: baseline'
git -C "$DIRECTORY_ROOT" commit --allow-empty -q -m 'test: second'

# run_publish_default [ENV=value...]: run the real publish script with no TAG,
# so it generates v<date>-<branch>.
run_publish_default() {
    env -u GH_RELEASE_EXISTS \
        GH_LOG="$FILE_LOG" \
        PATH="$DIRECTORY_BIN:$PATH" \
        "$@" \
        sh "$DIRECTORY_ROOT/scripts/release-publish.sh"
}

# run_publish_tag TAG [ENV=value...]: run it with an explicit tag.
run_publish_tag() {
    tag_release=$1
    shift
    env -u GH_RELEASE_EXISTS \
        GH_LOG="$FILE_LOG" \
        PATH="$DIRECTORY_BIN:$PATH" \
        TAG="$tag_release" \
        "$@" \
        sh "$DIRECTORY_ROOT/scripts/release-publish.sh"
}

HEAD_COMMIT=$(git -C "$DIRECTORY_ROOT" rev-parse HEAD)
BRANCH=$(git -C "$DIRECTORY_ROOT" symbolic-ref --short HEAD)
EXPECTED_TAG="v$(date +%F)-$BRANCH"

# A previous build left a VERSION in the build tree.  The publish path must
# package the current build, not this stale file.
mkdir -p "$DIRECTORY_ROOT/dataflow.out/build"
printf '1999-01-01-stale\n' > "$DIRECTORY_ROOT/dataflow.out/build/VERSION"

# --- a clean publish ---------------------------------------------------------
run_publish_default > "$DIRECTORY_TEST/publish.log" 2>&1 \
    || { sed 's/^/    /' "$DIRECTORY_TEST/publish.log" >&2; fail 'the clean publish failed'; }

TAG_COMMIT=$(git -C "$DIRECTORY_ROOT" rev-parse "$EXPECTED_TAG^{commit}")
[ "$TAG_COMMIT" = "$HEAD_COMMIT" ] || fail 'the tag is not on the released commit'
REMOTE_BRANCH=$(git -C "$DIRECTORY_REMOTE" rev-parse "refs/heads/$BRANCH")
[ "$REMOTE_BRANCH" = "$HEAD_COMMIT" ] || fail 'the branch was not pushed to the remote'
REMOTE_TAG=$(git -C "$DIRECTORY_REMOTE" rev-parse "refs/tags/$EXPECTED_TAG^{commit}")
[ "$REMOTE_TAG" = "$HEAD_COMMIT" ] || fail 'the tag was not pushed to the remote'
grep -F -q "release create $EXPECTED_TAG" "$FILE_LOG" || fail 'the release was not created'
grep -F -q "release-publish: $EXPECTED_TAG is published" "$DIRECTORY_TEST/publish.log" \
    || fail 'the publish did not report success'
[ -s "$DIRECTORY_ROOT/dataflow.out/release/gnome-filetype-integration-linux-x86_64.tar.gz" ] \
    || fail 'the publish produced no tarball'
EXPECTED_VERSION=$("$DIRECTORY_ROOT/dataflow.out/build/program/bin/filetype" --version | awk '{print $2}')
RELEASE_VERSION=$(cat "$DIRECTORY_ROOT/dataflow.out/release/VERSION")
[ "$RELEASE_VERSION" = "$EXPECTED_VERSION" ] \
    || fail "the release VERSION is $RELEASE_VERSION, not the built $EXPECTED_VERSION"
EXPECTED_TITLE_DATE=$(printf '%s' "$EXPECTED_VERSION" | cut -c1-10)
EXPECTED_TITLE_DETAIL=$(printf '%s' "$EXPECTED_VERSION" | cut -c12-)
EXPECTED_TITLE="$EXPECTED_TITLE_DATE — GNOME File Type Integration ($EXPECTED_TITLE_DETAIL)"
grep -F -q -- "--title $EXPECTED_TITLE" "$FILE_LOG" \
    || fail 'the release title does not put the date first'

# --- a second publish reuses the tag and re-uploads --------------------------
run_publish_default GH_RELEASE_EXISTS=1 > "$DIRECTORY_TEST/republish.log" 2>&1 \
    || { sed 's/^/    /' "$DIRECTORY_TEST/republish.log" >&2; fail 'the re-publish failed'; }
grep -F -q "release upload $EXPECTED_TAG" "$FILE_LOG" || fail 'the re-publish did not upload the assets'
grep -q -- '--clobber' "$FILE_LOG" || fail 'the re-publish did not replace the assets'
grep -q 'already exists on this commit' "$DIRECTORY_TEST/republish.log" \
    || fail 'the re-publish did not reuse the existing tag'

# --- a dirty tree is refused -------------------------------------------------
printf 'dirty\n' > "$DIRECTORY_ROOT/dirty.txt"
if run_publish_default > "$DIRECTORY_TEST/dirty.log" 2>&1; then
    fail 'the publish accepted a dirty tree'
fi
grep -q 'working tree has changes' "$DIRECTORY_TEST/dirty.log" \
    || fail 'the dirty-tree refusal is not explained'
rm -f "$DIRECTORY_ROOT/dirty.txt"

# --- a tag on another commit is refused --------------------------------------
FIRST_COMMIT=$(git -C "$DIRECTORY_ROOT" rev-list --max-parents=0 HEAD)
git -C "$DIRECTORY_ROOT" tag -a v9.9.9 -m 'an older release' "$FIRST_COMMIT"
if run_publish_tag v9.9.9 > "$DIRECTORY_TEST/tag.log" 2>&1; then
    fail 'the publish accepted a tag on another commit'
fi
grep -q 'not on' "$DIRECTORY_TEST/tag.log" || fail 'the tag-mismatch refusal is not explained'
if git -C "$DIRECTORY_REMOTE" rev-parse --verify --quiet 'refs/tags/v9.9.9' > /dev/null; then
    fail 'the publish pushed a tag that points at another commit'
fi

# --- a missing remote is refused with the setup command ----------------------
git -C "$DIRECTORY_ROOT" remote remove origin
if run_publish_default > "$DIRECTORY_TEST/remote.log" 2>&1; then
    fail 'the publish accepted a repository without the push remote'
fi
grep -q 'no .origin. remote' "$DIRECTORY_TEST/remote.log" \
    || fail 'the missing-remote refusal is not explained'
grep -q 'gh repo create' "$DIRECTORY_TEST/remote.log" \
    || fail 'the missing-remote refusal does not name the setup command'

# --- a detached checkout without a tag asks for TAG --------------------------
git -C "$DIRECTORY_ROOT" remote add origin "$DIRECTORY_REMOTE"
git -C "$DIRECTORY_ROOT" tag -d "$EXPECTED_TAG" >/dev/null
git -C "$DIRECTORY_ROOT" checkout --detach >/dev/null 2>&1
if run_publish_default > "$DIRECTORY_TEST/detached.log" 2>&1; then
    fail 'the publish invented a branch for a detached checkout'
fi
grep -q 'not on a branch' "$DIRECTORY_TEST/detached.log" \
    || fail 'the detached-checkout refusal is not explained'
grep -q 'set TAG explicitly' "$DIRECTORY_TEST/detached.log" \
    || fail 'the detached-checkout refusal does not ask for TAG'

pass_test "$NAME_TEST"

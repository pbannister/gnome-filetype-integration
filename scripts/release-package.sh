#!/bin/sh
#
# release-package.sh: turn a built tree into the files a release publishes.
#
# The build tree is dataflow.out/build/ (override with an argument or
# DIRECTORY_BUILD). It must contain a bin/ directory; share/ and README.md are
# packaged when present. Output goes to dataflow.out/release/ (override with
# DIRECTORY_RELEASE):
#
#   <project>-linux-<arch>.tar.gz  the products, under bin/ and share/
#   SHA256SUMS                     the digest of that tarball
#   VERSION                        the version the tarball carries
#   RELEASE-NOTES.md               the generated release notes
#
# Name the assets without a version, so
# releases/latest/download/<asset> works without an API call; a version can
# still be pinned by adding the tag to the path.
#
# Packing one build is deterministic: sorted names, no owner, one timestamp
# taken from the commit, and no gzip timestamp, so packing the same build twice
# yields one digest. Building again does not: the build counter changes.
#
# Environment:
#   PROJECT_NAME   the asset name piece (default: the repository directory name)
#   VERSION        the version to stamp (default: <build>/VERSION, else git)
#   REPOSITORY     owner/repo for the install line (default: the origin remote)
#
# See prompts/capabilities/04-release-and-publishing.md.
set -eu

DIRECTORY_SCRIPT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$DIRECTORY_SCRIPT/.." && pwd)

DIRECTORY_BUILD=${1:-"${DIRECTORY_BUILD:-$REPOSITORY_ROOT/dataflow.out/build}"}
DIRECTORY_RELEASE=${DIRECTORY_RELEASE:-"$REPOSITORY_ROOT/dataflow.out/release"}
DIRECTORY_STAGE="$DIRECTORY_RELEASE/stage"
PROJECT_NAME=${PROJECT_NAME:-$(basename "$REPOSITORY_ROOT")}

if [ ! -d "$DIRECTORY_BUILD" ]; then
    echo "release-package: no build tree: $DIRECTORY_BUILD (run make build first)" >&2
    exit 1
fi

if [ ! -d "$DIRECTORY_BUILD/bin" ]; then
    echo "release-package: the build tree has no bin/ directory: $DIRECTORY_BUILD" >&2
    echo "release-package: stage the products under bin/ (and share/ when needed)" >&2
    exit 1
fi

case "$(uname -m)" in
    x86_64 | amd64)
        ARCHITECTURE=x86_64
        ;;
    aarch64 | arm64)
        ARCHITECTURE=aarch64
        ;;
    *)
        echo "release-package: no release is built for machine $(uname -m)" >&2
        exit 1
        ;;
esac

version_from_git() {
    date_build=$(date +%F)
    branch_build=$(git -C "$REPOSITORY_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)
    hash_build=$(git -C "$REPOSITORY_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)
    suffix_changes=
    if [ -n "$(git -C "$REPOSITORY_ROOT" status --porcelain 2>/dev/null)" ]; then
        suffix_changes=-changes
    fi
    printf '%s-%s-%s%s' "$date_build" "$branch_build" "$hash_build" "$suffix_changes"
}

if [ -z "${VERSION:-}" ]; then
    if [ -f "$DIRECTORY_BUILD/VERSION" ]; then
        VERSION=$(cat "$DIRECTORY_BUILD/VERSION")
    else
        VERSION=$(version_from_git)
    fi
fi

repository_slug() {
    slug=$(git -C "$REPOSITORY_ROOT" remote get-url origin 2>/dev/null \
        | sed -e 's#.*github\.com[:/]##' -e 's#\.git$##') || slug=
    [ -n "$slug" ] || slug="OWNER/$PROJECT_NAME"
    printf '%s' "$slug"
}

REPOSITORY_SLUG=$(repository_slug)
FILE_TARBALL="$DIRECTORY_RELEASE/$PROJECT_NAME-linux-$ARCHITECTURE.tar.gz"

rm -rf "$DIRECTORY_RELEASE"
mkdir -p "$DIRECTORY_STAGE"

cp -R "$DIRECTORY_BUILD/bin" "$DIRECTORY_STAGE/bin"
if [ -d "$DIRECTORY_BUILD/share" ]; then
    cp -R "$DIRECTORY_BUILD/share" "$DIRECTORY_STAGE/share"
fi
if [ -f "$REPOSITORY_ROOT/README.md" ]; then
    cp "$REPOSITORY_ROOT/README.md" "$DIRECTORY_STAGE/README.md"
fi
printf '%s\n' "$VERSION" > "$DIRECTORY_STAGE/VERSION"

# One timestamp for every member, taken from the commit, and no gzip timestamp
# or original name, so the same build always packs to the same bytes.
FILE_MTIME=$(git -C "$REPOSITORY_ROOT" log -1 --format=%ct 2>/dev/null || date +%s)
tar --create --file - \
    --directory "$DIRECTORY_STAGE" \
    --sort=name --owner=0 --group=0 --numeric-owner --mtime="@$FILE_MTIME" \
    . | gzip -9n > "$FILE_TARBALL"

(
    cd "$DIRECTORY_RELEASE"
    sha256sum "$(basename "$FILE_TARBALL")" > SHA256SUMS
)
printf '%s\n' "$VERSION" > "$DIRECTORY_RELEASE/VERSION"

cat > "$DIRECTORY_RELEASE/RELEASE-NOTES.md" <<NOTES
# $PROJECT_NAME $VERSION

Built for linux-$ARCHITECTURE.

## Install

\`\`\`sh
curl -fsSL https://raw.githubusercontent.com/$REPOSITORY_SLUG/master/scripts/install.sh | sh
\`\`\`

The script takes the tarball from this release, checks it against
\`SHA256SUMS\`, and installs into \`\$HOME/.local\`. Set \`PREFIX\` to install
elsewhere, or \`VERSION\` to a tag to pin one. System integration stays a
deliberate step the script prints rather than performs.

## What is in the tarball

| Path | What it is |
| ---- | ---------- |
| \`bin/\` | the programs |
| \`share/\` | data the programs install beside them |
| \`VERSION\` | the version these programs report |

## Testing the download

\`\`\`sh
sha256sum -c SHA256SUMS
\`\`\`
NOTES

rm -rf "$DIRECTORY_STAGE"

echo "release-package: $(basename "$FILE_TARBALL")"
echo "release-package: SHA256SUMS"
echo "release-package: RELEASE-NOTES.md"
echo "release-package: version $VERSION, linux-$ARCHITECTURE"
exit 0

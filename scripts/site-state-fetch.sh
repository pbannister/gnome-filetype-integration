#!/bin/sh
#
# site-state-fetch.sh: gather live state and write it as KEY=value lines to
# the site state file that scripts/site-build.sh substitutes into the pages.
#
# The state file is generated output and must not be edited by hand.
#
# This is a portable template: it captures only git and host facts. A real
# project extends it with the values its dashboard shows, as __KEY__
# placeholders in site.in/dashboard.txt. A placeholder with no value renders
# as "unavailable", so the pages still build on a host where the project is
# not installed.
#
# Convention: a state fetch that reads hardware, systemctl, or the network
# MUST run on the owning host, not on the build host, so the value is measured
# where the service runs (for example `ssh <host> 'make state'`).
#
# Values are sanitized before they are written: $HOME becomes ~ and HTML is
# escaped, because the values land in HTML and the publish gate refuses
# absolute home paths.
#
# Usage: site-state-fetch.sh [OUTPUT_FILE]
# The default OUTPUT_FILE is dataflow.out/site-state.txt relative to the
# repository root.
set -eu

DIRECTORY_SCRIPT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$DIRECTORY_SCRIPT/.." && pwd)
OUTPUT_FILE=${1:-"$REPOSITORY_ROOT/dataflow.out/site-state.txt"}

# tidy: sanitize one value for publication (home path -> ~, HTML escaped).
tidy() {
    printf '%s' "$1" | sed "s|$HOME|~|g" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'
}

# symbolic-ref (not rev-parse --abbrev-ref) so a detached HEAD reports
# "unknown" instead of the literal "HEAD".
state_fetched=$(tidy "$(date -Is 2>/dev/null || date)")
state_host=$(tidy "$(hostname 2>/dev/null || echo unknown)")
state_branch=$(tidy "$(git -C "$REPOSITORY_ROOT" symbolic-ref -q --short HEAD 2>/dev/null || echo unknown)")
state_commit=$(tidy "$(git -C "$REPOSITORY_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)")

mkdir -p "$(dirname "$OUTPUT_FILE")"

cat > "$OUTPUT_FILE" <<EOF
FETCHED=$state_fetched
HOST=$state_host
BRANCH=$state_branch
COMMIT=$state_commit
EOF

echo "site-state-fetch: wrote $OUTPUT_FILE"
exit 0

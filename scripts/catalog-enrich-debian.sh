#!/bin/sh
#
# catalog-enrich-debian.sh: fill missing catalog homepages from Debian tracker
# package pages.
#
# This is an explicit maintenance command, not part of `make build` or
# `make test`: it uses the network. It reads each catalog entry that has an apt
# package but no homepage, fetches https://tracker.debian.org/pkg/<package>,
# extracts the upstream homepage link, and writes it into the catalog.
#
# Usage: scripts/catalog-enrich-debian.sh [--dry-run] [--workers N] [--json]
set -eu

DIRECTORY_SCRIPT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$DIRECTORY_SCRIPT/.." && pwd)

PYTHONPATH="$REPOSITORY_ROOT/sources${PYTHONPATH:+:$PYTHONPATH}" \
    exec python3 -m filetype_integration.catalog_enrich --source debian "$@"

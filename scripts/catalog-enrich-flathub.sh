#!/bin/sh
#
# catalog-enrich-flathub.sh: fill missing catalog homepages from Flathub.
#
# This is an explicit maintenance command, not part of `make build` or
# `make test`: it uses the network. It reads each catalog entry that has a
# Flatpak id but no homepage, fetches the Flathub page, extracts the
# "Project Website" link, and writes the result into the catalog.
#
# Usage: scripts/catalog-enrich-flathub.sh [--dry-run] [--workers N] [--json]
set -eu

DIRECTORY_SCRIPT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$DIRECTORY_SCRIPT/.." && pwd)

PYTHONPATH="$REPOSITORY_ROOT/sources${PYTHONPATH:+:$PYTHONPATH}" \
    exec python3 -m filetype_integration.catalog_enrich "$@"

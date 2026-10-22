#!/bin/sh
#
# filetype_env.sh: a sandboxed desktop for the file type tests.
#
# Source this file, then call filetype_sandbox.  It creates a temporary HOME,
# XDG data/config/cache directories, and an XDG_DATA_DIRS tree holding the
# fixture MIME database and fixture desktop entries.  No test reads or writes
# the real desktop.
#
# The staged program is preferred, because it carries the generated version
# and is what an install would copy.  A source-tree fallback keeps a single
# test runnable with `sh tests/15-file-identifier.sh` before `make build`.

filetype_sandbox() {
    DIRECTORY_TEST=$(mktemp -d)
    mkdir -p "$DIRECTORY_TEST/home" "$DIRECTORY_TEST/data" "$DIRECTORY_TEST/config" \
             "$DIRECTORY_TEST/cache" "$DIRECTORY_TEST/xdg" "$DIRECTORY_TEST/xdgconfig"
    cp -R "$REPOSITORY_ROOT/dataflow.in/mime/." "$DIRECTORY_TEST/xdg/mime/"
    cp -R "$REPOSITORY_ROOT/dataflow.in/applications/." "$DIRECTORY_TEST/xdg/applications/"
    cp "$REPOSITORY_ROOT/dataflow.in/mimeapps.list" "$DIRECTORY_TEST/config/mimeapps.list"

    HOME="$DIRECTORY_TEST/home"
    XDG_DATA_HOME="$DIRECTORY_TEST/data"
    XDG_CONFIG_HOME="$DIRECTORY_TEST/config"
    XDG_CACHE_HOME="$DIRECTORY_TEST/cache"
    XDG_CONFIG_DIRS="$DIRECTORY_TEST/xdgconfig"
    XDG_DATA_DIRS="$DIRECTORY_TEST/xdg"
    XDG_CURRENT_DESKTOP=
    FILETYPE_MIME_TYPES_FILE="$DIRECTORY_TEST/xdg/mime/mime.types"
    FILETYPE_INTEGRATION_NO_GIO=1
    FILETYPE_EXECUTABLE="$REPOSITORY_ROOT/dataflow.out/build/program/bin/filetype"
    export HOME XDG_DATA_HOME XDG_CONFIG_HOME XDG_CACHE_HOME XDG_CONFIG_DIRS \
           XDG_DATA_DIRS XDG_CURRENT_DESKTOP FILETYPE_MIME_TYPES_FILE \
           FILETYPE_INTEGRATION_NO_GIO FILETYPE_EXECUTABLE

    if [ -x "$REPOSITORY_ROOT/dataflow.out/build/program/bin/filetype" ]; then
        FILETYPE="$REPOSITORY_ROOT/dataflow.out/build/program/bin/filetype"
    else
        FILETYPE="$REPOSITORY_ROOT/sources/tools/filetype"
        PYTHONPATH="$REPOSITORY_ROOT/sources${PYTHONPATH:+:$PYTHONPATH}"
        export PYTHONPATH
    fi
    FIXTURES="$REPOSITORY_ROOT/dataflow.in/fixtures"
    FILETYPE_FIXTURES="$FIXTURES"
    export FILETYPE_FIXTURES
}

filetype_cleanup() {
    if [ -n "${DIRECTORY_TEST:-}" ] && [ -d "$DIRECTORY_TEST" ]; then
        rm -rf "$DIRECTORY_TEST"
    fi
}

# json_field FILE EXPRESSION: evaluate a Python expression over the parsed
# JSON document, where `d` is the document.  Prints the result.
json_field() {
    python3 - "$1" "$2" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as handle:
    document = json.load(handle)
value = eval(sys.argv[2], {"__builtins__": {}}, {"d": document})
print(value)
PY
}

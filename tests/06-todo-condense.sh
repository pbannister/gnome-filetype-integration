#!/bin/sh
#
# Condensed TODO test (scripts/site-condense.sh).
#
# Tier: tool-gated (python3). The condenser reads this repository's own
# TODO.md, so the test builds a small throwaway repository around a copy of
# the script and a fixture TODO.md, and checks what the page must do:
#
#   * nested items stay nested, inside their parent's list item;
#   * continuation lines stay with the item they belong to;
#   * completed items are counted, never listed;
#   * the list markup is balanced and no bullet marker leaks into the text.
set -eu

DIRECTORY_SCRIPT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$DIRECTORY_SCRIPT/.." && pwd)

. "$DIRECTORY_SCRIPT/lib/test_helpers.sh"
skip_unless_tool python3

DIRECTORY_TEST=$(mktemp -d)
trap 'rm -rf "$DIRECTORY_TEST"' EXIT HUP INT TERM

fail() {
    echo "06-todo-condense: $1" >&2
    exit 1
}

mkdir -p "$DIRECTORY_TEST/scripts" "$DIRECTORY_TEST/site.in" \
    "$DIRECTORY_TEST/prompts" "$DIRECTORY_TEST/documents" "$DIRECTORY_TEST/records"
cp "$REPOSITORY_ROOT/scripts/site-condense.sh" "$DIRECTORY_TEST/scripts/site-condense.sh"
cp "$REPOSITORY_ROOT/site.in/template.html" "$DIRECTORY_TEST/site.in/template.html"

cat > "$DIRECTORY_TEST/TODO.md" <<'FIXTURE'
# TODO

## Open Questions

* [ ] first open item with a continuation
      that runs onto the next line.
* [ ] parent item with a nested list:
    * [ ] nested item one.
    * [ ] nested item two,
          continued under itself.
* [ ] last open item.

## Recently Completed

* [x] a completed item that must not be listed.
* [X] another completed item.
FIXTURE

if ! output_condense=$(cd "$DIRECTORY_TEST" && sh scripts/site-condense.sh 2>&1); then
    fail "condenser failed: $output_condense"
fi

[ -s "$DIRECTORY_TEST/site.out/todo.html" ] || fail 'todo.html was not written'

python3 - "$DIRECTORY_TEST/site.out/todo.html" <<'PYTHON_CHECK' || fail 'the condensed todo is wrong'
import pathlib
import re
import sys

text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
body = text[text.index("</head>"):]

# balanced markup, and no bullet marker leaking into the page text
assert body.count("<ul>") == body.count("</ul>"), "unbalanced <ul>"
assert body.count("<li>") == body.count("</li>"), "unbalanced <li>"
assert "* [ ]" not in body, "a bullet marker leaked into the page text"
assert "[x]" not in body and "[X]" not in body, "a completed item was listed"

# the nested list sits inside its parent item, not beside it
parent = body.index("parent item with a nested list")
nested = body.index("nested item one")
parent_close = body.index("</li>", parent)
assert parent < nested < parent_close, "the nested list is not inside its parent item"
assert "<ul>" in body[parent:parent_close], "the nested list is not opened inside the parent"

# continuation lines joined to the item above them
assert "first open item with a continuation that runs onto the next line" in body, \
    "a top-level continuation line was not joined"
assert "nested item two, continued under itself" in body, \
    "a nested continuation line was not joined"

# completed items are summarised, not listed
assert re.search(r"[0-9]+ open item\(s\), 2 completed", body), "the counts are wrong"
assert "a completed item that must not be listed" not in body, "a completed item was listed"

# every open item appears exactly once
for text_item in ("first open item", "parent item", "nested item one",
                  "nested item two", "last open item"):
    assert 1 == body.count(text_item), f"{text_item} appears {body.count(text_item)} times"
PYTHON_CHECK

echo '06-todo-condense: ok'
exit 0

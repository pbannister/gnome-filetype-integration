#!/bin/sh
#
# Test the identifier: magic content, extension hints, agreement, conflict,
# generic containers, and missing files.
#
# Tier: portable (needs the `file` utility; skipped cleanly without it).
set -eu

DIRECTORY_SCRIPT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$DIRECTORY_SCRIPT/.." && pwd)
. "$DIRECTORY_SCRIPT/lib/filetype_env.sh"
. "$DIRECTORY_SCRIPT/lib/test_helpers.sh"
skip_unless_tool file
skip_unless_tool python3

filetype_sandbox
trap filetype_cleanup EXIT HUP INT TERM

fail() {
    echo "15-file-identifier: $1" >&2
    exit 1
}

identify_json() {
    "$FILETYPE" identify --json "$1"
}

check_field() { # <file> <python expression over d.files[0]> <expected>
    output=$(identify_json "$1") || fail "identify failed for $1"
    actual=$(printf '%s' "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
f = d['files'][0]
print($2)
") || fail "could not evaluate the JSON for $1"
    [ "$actual" = "$3" ] || fail "$1: expected $2 = '$3', got '$actual'"
}

# 1. Content and name agree.
check_field "$FIXTURES/sample.png" "f['mime']" "image/png"
check_field "$FIXTURES/sample.png" "f['source']" "agreement"
check_field "$FIXTURES/sample.pdf" "f['mime']" "application/pdf"

# 2. A text format whose magic is generic takes its type from the name.
check_field "$FIXTURES/sample.md" "f['mime']" "text/markdown"
check_field "$FIXTURES/sample.py" "f['mime']" "text/x-python"

# 3. A renamed file reports the conflict and keeps the content type.
check_field "$FIXTURES/sample-renamed.txt" "f['mime']" "image/png"
check_field "$FIXTURES/sample-renamed.txt" "f['conflict']['name_mime']" "text/plain"
check_field "$FIXTURES/sample-renamed.txt" "f['source']" "content"

# 4. An empty file falls back to the extension.
check_field "$FIXTURES/sample-empty.png" "f['mime']" "image/png"
check_field "$FIXTURES/sample-empty.png" "f['extension']['mime']" "image/png"

# 5. A zip-based document prefers the specific name over the container magic.
check_field "$FIXTURES/sample-container.docx" "f['mime']" "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
check_field "$FIXTURES/sample-container.docx" "f['magic']['mime']" "application/zip"
check_field "$FIXTURES/sample.docx" "f['mime']" "application/vnd.openxmlformats-officedocument.wordprocessingml.document"

# 6. A compound extension beats the shorter one.
check_field "$FIXTURES/sample.tar.gz" "f['mime']" "application/x-compressed-tar"
check_field "$FIXTURES/sample.tar.gz" "f['extension']['suffix']" "tar.gz"

# 7. An unknown extension is reported, and the content still wins.
check_field "$FIXTURES/sample.custom" "f['mime']" "application/x-custom-format"
check_field "$FIXTURES/sample.custom" "f['extension']['known']" "True"

# 8. A missing file is a finding, not a crash.
output=$(identify_json "$DIRECTORY_TEST/does-not-exist.xyz" 2>/dev/null) || true
[ -n "$output" ] || fail "identify crashed on a missing file"
printf '%s' "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)['files'][0]
assert d['exists'] is False, d
assert d['mime'] == 'application/x-missing-file', d
" || fail "the missing-file report is wrong"

# 8.1 A PHP template starts with an HTML body; the name still decides.
check_field "$FIXTURES/sample-template.php" "f['mime']" "application/x-php"
check_field "$FIXTURES/sample-template.php" "f['description']" "PHP script"
check_field "$FIXTURES/sample-template.php" "f['source']" "name"
check_field "$FIXTURES/sample-template.php" "f['conflict'] is None" "True"
check_field "$FIXTURES/sample-code.php" "f['mime']" "application/x-php"
check_field "$FIXTURES/sample-page.jsp" "f['mime']" "application/x-jsp"
check_field "$FIXTURES/sample-page.jsp" "f['category']" "code"
check_field "$FIXTURES/sample-view.vue" "f['mime']" "application/x-vue"
check_field "$FIXTURES/sample-template.erb" "f['mime']" "application/x-erb"
check_field "$FIXTURES/sample-component.jsx" "f['mime']" "application/x-jsx"
check_field "$FIXTURES/sample-component.tsx" "f['mime']" "application/x-tsx"
check_field "$FIXTURES/sample-tileset.tsx" "f['mime']" "application/x-tiled-tsx"
check_field "$FIXTURES/sample-page.shtml" "f['mime']" "application/x-ssi"

# 8.2 An AppImage is an ELF executable; the name gives the bundle type.
check_field "$FIXTURES/sample.AppImage" "f['mime']" "application/vnd.appimage"
check_field "$FIXTURES/sample.AppImage" "f['description']" "AppImage application bundle"
check_field "$FIXTURES/sample.AppImage" "f['category']" "package"
check_field "$FIXTURES/sample.AppImage" "f['conflict'] is None" "True"

# 8.3 AI model formats the shared MIME database does not know.  The bytes are
#     generic, so the extension is the deciding witness.
for model in \
    "gguf:application/x-gguf:GGUF model" \
    "ggml:application/x-ggml:GGML model" \
    "safetensors:application/x-safetensors:Safetensors model" \
    "onnx:application/x-onnx:ONNX model" \
    "tflite:application/x-tflite:TensorFlow Lite model" \
    "mlmodel:application/x-mlmodel:Core ML model" \
    "keras:application/x-keras:Keras model" \
    "pth:application/x-pytorch:PyTorch model" \
    "ckpt:application/x-torch-checkpoint:PyTorch checkpoint"
do
    suffix=${model%%:*}
    rest=${model#*:}
    mime=${rest%%:*}
    description=${rest#*:}
    check_field "$FIXTURES/sample.$suffix" "f['mime']" "$mime"
    check_field "$FIXTURES/sample.$suffix" "f['description']" "$description"
    check_field "$FIXTURES/sample.$suffix" "f['category']" "ai"
done
check_field "$FIXTURES/sample.gguf" "f['source']" "name"
check_field "$FIXTURES/sample.gguf" "f['extension']['suffix']" "gguf"

# 8.4 KML is an XML type, and the name gives the more specific geographic type.
check_field "$FIXTURES/sample.kml" "f['mime']" "application/vnd.google-earth.kml+xml"
check_field "$FIXTURES/sample.kml" "f['description']" "KML geographic data"
check_field "$FIXTURES/sample.kml" "f['category']" "data"

# 9. The command-line exit status distinguishes a missing file.
if "$FILETYPE" identify "$DIRECTORY_TEST/does-not-exist.xyz" >/dev/null 2>&1; then
    fail 'identify exited zero for a missing file'
fi

# 10. The document carries its evidence and reasons.
output=$(identify_json "$FIXTURES/sample-renamed.txt") || fail 'identify failed'
printf '%s' "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
f = d['files'][0]
assert d['schema'] == 1
assert 0 <= f['confidence'] <= 1
assert f['magic']['mime'] == 'image/png'
assert f['extension']['mime'] == 'text/plain'
assert f['reasons']
assert f['category'] == 'image'
" || fail 'the identification document is incomplete'

echo '15-file-identifier: ok'
exit 0

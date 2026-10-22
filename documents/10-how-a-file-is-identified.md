# How a File Is Identified

The identifier answers one question — *what is this file?* — with evidence a
person can check. It never trusts a single witness, and it never hides a
disagreement.

## Two witnesses

| Witness | Source | What it is good at | What it misses |
| ------- | ------ | ------------------ | -------------- |
| Content | `file --mime-type --mime-encoding`, backed by `/usr/share/misc/magic.mgc` | renamed files, extensionless downloads, containers | generic answers such as `text/plain` or `application/zip` |
| Name | shared-mime-info `globs2`, `aliases`, `subclasses`, package XML, and `mime.types` | specific formats whose bytes are generic, such as `.md`, `.py`, or an empty `.png` | a file whose name was changed or removed |

The MIME index is read directly from the same files the desktop uses:

- `$XDG_DATA_HOME/mime/globs2` and each `$XDG_DATA_DIRS/*/mime/globs2`
- `mime/aliases`, `mime/subclasses`, and `mime/packages/*.xml`
- `/etc/mime.types` and `/etc/httpd/mime.types`

The fixtures under `dataflow.in/mime/` mirror that layout, which is how the
tests run without touching the real desktop.

## The decision table

| Content | Name | Chosen type | Confidence | Report |
| ------- | ---- | ----------- | ---------- | ------ |
| specific, agrees with the name | known | the more specific name type | high | agreement |
| specific, disagrees with the name | known | the content type | medium | conflict, both types |
| generic (`text/plain`, `application/zip`, `application/octet-stream`, `application/x-empty`) | known | the name type | medium | name supplies the type |
| specific | unknown | the content type | high | no known extension |
| unavailable | known | the name type | low | libmagic was unavailable |
| generic | unknown | the generic content type | low | unknown file |

A template language is a deliberate exception. PHP often begins with an HTML
body, so libmagic reports `text/html` while the name says `application/x-php`.
The name wins for PHP and the other template/script types listed in
`TEMPLATE_MIME_TYPES`; the HTML is the template body, not the file's kind.
libmagic's `text/x-php` is also aliased to `application/x-php`, because the two
databases spell the same language differently.

A generic content type does not mean "unidentified": it means the bytes carry
no format signature, so the name is the better evidence. A *specific* content
type is different — if the bytes say PNG and the name says `.txt`, the bytes
win and the conflict is printed.

The subtype relationship is used to prefer the more specific name. A `.docx`
is a subclass of `application/zip`; a `.tar.gz` is a subclass of
`application/gzip`. The identifier prefers the subclass, which is why a Word
document is not reported as a plain ZIP.

Odd ancestry is handled separately. Shared-mime-info records
`text/x-python` as a subclass of `application/x-executable`, so a debugger
would otherwise appear as a Python handler. The handler search widens only
through generic text and container parents, never through that edge.

## Worked examples

```sh
$ filetype identify --json invoice.pdf
# content: application/pdf  name: .pdf -> application/pdf
# mime: application/pdf, source: agreement, confidence: 0.97

$ filetype identify holiday-photo.txt
# content: image/png  name: .txt -> text/plain
# mime: image/png, source: content, confidence: 0.82
# conflict: "The bytes look like PNG image but the name suggests plain text
#            document. The bytes win; the file may have been renamed."

$ filetype identify empty.png
# content: application/x-empty  name: .png -> image/png
# mime: image/png, source: name, confidence: 0.80

$ filetype identify notes.scad
# content: text/plain  name: .scad -> application/x-openscad
# mime: application/x-openscad, source: name, confidence: 0.80
```

## What the report contains

`filetype identify --json` returns one object per file:

- `mime`, `description`, `category`, `category_label`
- `source` (`agreement`, `content`, `name`, `filesystem`, `fallback`) and
  `confidence` with a label
- `magic`: the MIME type, encoding, `file` description, and any error
- `extension`: the suffix, the MIME type the name implies, alternatives, and
  whether the extension is known
- `conflict`: the two types, the resolution, and a sentence for a person
- `reasons`: the evidence in the order it was considered
- `applications`: installed, available, default, and notes, when applications
  were requested

The document is stable within `"schema": 1`.

## Limits

- A forged or unusual file can fool any magic database. The conflict report is
  the protection: it says which witness won and shows the other.
- An extension index is a hint, not a guarantee. The identifier never claims a
  name type when the bytes are specific and disagree.
- The `file` utility is an external program. When it is missing, identification
  continues with the name and says so.
- A file inside an archive is not identified. The archive is identified, and
  the chooser can open it with an archive manager.
- A MIME type that no installed application handles is not a failure of
  identification. It is the case this project exists to help with.

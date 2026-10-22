# Record: PHP templates identified as PHP, not HTML

## Why it happened

A PHP file often begins with an HTML document. libmagic reported
`text/html`; the extension database reported `application/x-php`. The
identifier's conflict rule preferred specific content, so the file became an
HTML document and the offered applications were HTML viewers and browsers.

A second split made the problem harder: libmagic spells the language
`text/x-php`, while shared-mime-info uses `application/x-php`. The two were
treated as different types.

## Fix (applied, verified)

- `text/x-php` and `application/x-httpd-php` are built-in aliases of
  `application/x-php`, including in handler matching.
- A template-language exception recognises that the HTML body is the template
  content, not the file's kind. When the name says PHP (or JSP/ASP/ERB) and the
  content is HTML, XHTML, XML, or plain text, the name supplies the type with
  high confidence and no conflict.
- The fixture database now knows `application/x-php` and its `.php`/`.phtml`
  globs.
- Two fixtures cover the cases:
  - `sample-template.php` begins with `<html>` and libmagic says HTML;
  - `sample-code.php` begins with `<?php` and libmagic says PHP.

## Verification

- `make test` on 2026-10-22: all 27 test scripts passed.
- `tests/15-file-identifier` asserts both PHP fixtures identify as
  `application/x-php`, with “PHP script”, source `name` for the HTML-first file,
  and no conflict.
- The real command line reports:
  - type: PHP script (`application/x-php`);
  - category: Source code;
  - libmagic: `text/html`;
  - recommendations: Bluefish, Text Editor, VS Code, Helix, Vim, gedit, and
    other code editors rather than HTML viewers.
- The installed copy was not updated, per the owner's manual-install
  preference. `make install` applies the fix.

## Commits

- `7d1bb22` fix: identify PHP templates as PHP, not HTML

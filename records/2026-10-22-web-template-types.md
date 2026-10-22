# Record: web template source is not HTML

## Outcome

The PHP fix generalised into a built-in set of web application source types
whose bytes are HTML-shaped but which are not pages a browser should render:

| Kind | MIME type | Extensions |
| ---- | --------- | ---------- |
| JavaServer Pages | `application/x-jsp` | `.jsp`, `.jspx`, `.jspf` |
| ASP.NET | `application/x-aspx` | `.aspx`, `.ascx`, `.asmx`, `.ashx`, `.asax` |
| Razor | `application/x-razor` | `.cshtml`, `.vbhtml` |
| Embedded Ruby | `application/x-erb` | `.erb`, `.rhtml` |
| Embedded JavaScript | `application/x-ejs` | `.ejs` |
| Handlebars | `application/x-handlebars` | `.hbs`, `.handlebars` |
| Mustache | `application/x-mustache` | `.mustache` |
| Twig | `text/x-twig` | `.twig` |
| Liquid | `application/x-liquid` | `.liquid` |
| Nunjucks | `application/x-nunjucks` | `.njk`, `.nunjucks` |
| Jinja | `application/x-jinja2` | `.jinja`, `.jinja2`, `.j2` |
| Pug | `application/x-pug` | `.pug`, `.jade` |
| Haml | `application/x-haml` | `.haml` |
| Slim | `application/x-slim` | `.slim` |
| ColdFusion | `application/x-coldfusion` | `.cfm`, `.cfml` |
| ASP | `application/x-asp` | `.asp` |
| Vue | `application/x-vue` | `.vue` |
| Svelte | `application/x-svelte` | `.svelte` |
| Astro | `application/x-astro` | `.astro` |
| React JSX | `application/x-jsx` | `.jsx` |
| React TSX | `application/x-tsx` | `.tsx` (when the bytes are JavaScript/HTML, not Tiled XML) |
| Server-side includes | `application/x-ssi` | `.shtml` |

All are categorised as code, not text or HTML. The template exception in the
identifier keeps the language name when libmagic reports HTML, XHTML, XML, plain
text, or JavaScript.

`.tsx` needs an extra rule: the shared MIME database claims it for Tiled
tilesets. A `.tsx` file whose bytes are XML stays Tiled; one whose bytes are
JavaScript or HTML is React TSX.

## Verification

- `make test` on 2026-10-22: all 27 test scripts passed.
- Fixtures for JSP, Vue, ERB, JSX, TSX, Tiled TSX, and SSI all identify with the
  intended type and category.
- `tests/15-file-identifier` checks the MIME type, and the JSX/TSX/Tiled
  distinction.
- `tests/20-mime-index` includes the built-in template types.
- The installed copy was not updated, per the owner's manual-install preference.

## Commits

- `083c695` feat: recognize web template source instead of rendering HTML

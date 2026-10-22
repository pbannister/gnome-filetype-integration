# Record: About URL candidates and live fallback

## Outcome

The About link no longer trusts one compile-time URL. Each application exposes
an ordered candidate list built from the AppStream project page, the catalog
`homepage`, the vendor URL, Flathub, Snapcraft, and the distribution package
page. Clicking About probes the candidates with a short HTTP HEAD request,
retries a one-byte GET when HEAD is rejected, and opens the first page that
answers. A missing page moves to the next candidate; if none answer, the
chooser says so and lists what it tried.

The catalog gained an optional `homepage` field; 37 applications name their
project page. The JSON output now carries both `about_url` (first candidate) and
`about_urls` (the full ordered list).

## Decisions

- Probe on click rather than at build or window-open time: the user asked for a
  quick check, and a check at open time would delay the chooser for every row.
- Cache a probe result for five minutes in memory, so reopening or clicking
  twice does not repeat the request.
- Treat HEAD 400/403/405/501 and transport failures as a reason to try GET with
  `Range: bytes=0-0`. Many sites reject HEAD but are alive.
- Use AppStream first for an installed application, then the catalog and its
  install hints. This keeps the project page preferred when it exists.
- Send only the User-Agent and an Accept header. No file content, path, or
  detected type is sent.
- Test the probe against a loopback HTTP server: 404, 200, and a server that
  answers 405 to HEAD and 200 to GET.

## Verification

- `make test` on 2026-10-22: all 25 test scripts passed.
- `tests/40-about-links`: missing page false, live page true, HEAD-rejected
  page true through GET, first live candidate selected, all-missing reported,
  cache prevents a second request, and GIMP's candidate list is
  `gimp.org`, Flathub, then the Ubuntu package page.
- Real probe: `https://www.gimp.org/this-page-does-not-exist-filetype-check`
  returned false and the next candidate `https://www.gimp.org/` returned true.
- `tests/82-about-link`: clicking the link with a stubbed probe calls the
  opener and prints `ABOUT-CLICK ok`; the Run button still streams output.
- The live desktop remains clean: no handler entry, launcher, icon, manifest,
  or `mimeapps.list` change remains.

## Commits

- `b81a822` feat: probe About candidates and fall back when a site is gone

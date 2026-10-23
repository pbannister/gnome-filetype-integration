# Feature: File Type Integration

## Purpose

A Linux desktop may know the name of a file type without having any application
that can open it. This feature identifies a file from its content and its name,
finds every application that can consume it, and offers those choices on the
desktop and on the command line, so a downloaded file with an unhandled type is
never a dead end.

## Requirements

- `FILETYPE-R001` — Identification must use the libmagic database through the `file` utility as one witness and the shared-mime-info glob database as an independent second witness.
- `FILETYPE-R002` — Identification must report the chosen MIME type, a human description, a category, the confidence, the evidence from each witness, and the reasons for the decision.
- `FILETYPE-R003` — When the bytes and the name disagree, identification must report the conflict and choose the specific content type rather than silently trusting either witness.
- `FILETYPE-R004` — Extension resolution must support compound extensions, case-insensitive matching, aliases, subclass relationships, and the `mime.types` files in addition to the shared-mime-info globs.
- `FILETYPE-R005` — Application discovery must read the installed desktop entries and the MIME default files, so a proposal reflects the applications actually present on the machine.
- `FILETYPE-R006` — The project must ship a curated application catalog that records, for every application, a purpose, a maturity estimate, a popularity estimate, a usefulness estimate, the types it handles, and at least one install hint.
- `FILETYPE-R007` — The ranked application list must put installed applications before applications that are not installed, and must put the desktop default and an exact MIME match first within the installed set.
- `FILETYPE-R008` — For every known file type, the catalog and the installed applications together must yield at least one candidate application; a build must fail rather than publish a type with no candidate.
- `FILETYPE-R009` — The graphical chooser must show the file facts, the evidence, the installed applications, the applications worth installing, the install commands, and the equivalent command-line invocations.
- `FILETYPE-R010` — The graphical chooser must not execute, modify, or upload the file; opening the file is a separate action the user takes.
- `FILETYPE-R011` — The desktop integration must register a handler entry for every known file type so the chooser appears in the desktop's Open With list even when a working handler already exists.
- `FILETYPE-R012` — The desktop integration must set the chooser as the default only for a type with no installed application, or for a default whose entry or program is missing, and must never replace a working user default.
- `FILETYPE-R013` — The desktop integration must write a manifest recording the files it wrote and the previous default of every type it changed, so uninstall can reverse the change without guessing.
- `FILETYPE-R014` — Uninstall must restore a previous default only while the chooser still owns it, and must keep and report a choice the user made after installing.
- `FILETYPE-R015` — The Nautilus right-click extension is optional and must be installed only when the Nautilus Python bindings are available; its absence must not disable the double-click handler or the command line.
- `FILETYPE-R016` — The command line must expose identification, application listing, opening, directory scanning, handler status, handler installation, handler removal, type inspection, catalog inspection, and diagnostics, with a stable JSON document for each.
- `FILETYPE-R017` — The command line must not require a graphical session, and the graphical chooser must not be required to use any capability.
- `FILETYPE-R018` — The tool must collect no telemetry and make no network request except the user-initiated About availability check, which may issue one short HEAD or GET request per candidate page, at most once per site per day, and nothing else.
- `FILETYPE-R019` — File opening must pass the file as one argument vector element, never through a shell, and must report a launcher that is registered but whose program is missing.
- `FILETYPE-R020` — Tests must run against a sandboxed `HOME` and sandboxed XDG directories, must not change the real desktop, and must classify the graphical, Nautilus, and live checks as tool-gated.
- `FILETYPE-R021` — The tool must report the libmagic database, MIME database, desktop entries, GTK, catalog, and handler state through a diagnostics command.
- `FILETYPE-R022` — A directory scan must report, per file, whether an installed application can open it, and must offer an exit status that lets a script fail when at least one file needs help.
- `FILETYPE-R023` — Each application row in the chooser must place its action button on the left and offer an About link beside the application name; the link must open a dialog listing at least two candidate pages where possible, grouped by category and sorted by relevance, with each link initially disabled until a concurrent HTTP HEAD request succeeds.
- `FILETYPE-R024` — The install dialog must offer a Run action for each install hint and show the command's output and exit status as it runs.
- `FILETYPE-R025` — The chooser's own desktop entry must not appear in the list of installed applications.
- `FILETYPE-R026` — Each chooser process must use a distinct application identity so another session or a test cannot remote-activate it; every window must close through its Close control, the Escape key, and the application Quit action.
- `FILETYPE-R027` — The tool must record each About site visited with the date, result, and HTTP status, must not visit the same site more than once per local day, and must expose the history through the command line.
- `FILETYPE-R028` — A package search page must not be used as an About candidate unless its content is fetched and checked for a useful result; direct package pages are preferred.
- `FILETYPE-R029` — A catalog application with a Flathub id but no homepage must take its project website from the Flathub page's Project Website link, recorded as the catalog homepage.
- `FILETYPE-R030` — A catalog application with an apt package but no homepage must take its upstream homepage from the Debian tracker package page, recorded as the catalog homepage.
- `FILETYPE-R031` — A template or scripting language whose body is HTML, such as PHP, must be identified by its language name rather than as HTML, and its libmagic alias must resolve to the same MIME type.
- `FILETYPE-R032` — The built-in template set must include JSP, ASP.NET, Razor, ERB, EJS, Handlebars, Mustache, Twig, Liquid, Nunjucks, Jinja, Pug, Haml, Slim, ColdFusion, Vue, Svelte, Astro, JSX/TSX, and server-side includes, with a code category and description.
- `FILETYPE-R033` — The main window must use four tabs: Installed, Relevant, About, and Why. About must initially show the project version, the GitHub repository link, and the labs.bannister.us project link; clicking an application's About action must replace that page with the candidate list for the application. Why must contain the identification evidence and the command-line equivalents without collapsing either section.
- `FILETYPE-R034` — A file named `*.AppImage` must be identified as an AppImage application bundle, with the package category, even when libmagic reports the underlying ELF executable.
- `FILETYPE-R035` — The About candidates for an installed application must prefer a curated catalog homepage over stale AppStream metadata, and must not guess a distribution package from an AppImage path or a reverse-DNS desktop id.

## Behavior

- Double-clicking a file with no installed application opens the Discover Applications…, which explains the problem and offers installable applications.
- Right-clicking a file offers the chooser and the inspector when the Nautilus extension is active.
- Opening a file with an already-installed application uses the desktop entry's `Exec` line, with the file substituted as one argument.
- Installing the handler records every file and every changed default; uninstalling it puts the desktop back and preserves later user choices.
- `filetype scan --unhandled-only --fail-on-unhandled` exits 4 when at least one file has no installed application.
- A missing file is reported as a finding with exit status 1, not as a crash.

## Dependencies

- None.

# Record: tabbed Installed, Relevant, and About window

## Outcome

The main chooser is now tabbed:

- **Installed** — the applications already present on the machine.
- **Relevant** — the applications worth installing, with the install action.
- **About** — initially the project itself: version, build, GitHub repository,
  and the labs.bannister.us project page.

Clicking an application's **About** action switches to the About tab and replaces
the project information with that application's About content: grouped project,
repository, documentation, reference, community, store, and package links. The
links start disabled and are probed concurrently, exactly as before. A **Project
information** button returns to the project page.

The file card and the identification warning stay above the tabs. The
identification details and command-line equivalents remain below the tabs as
collapsed expanders. The footer actions remain common to the window.

The main window is titled **Discover Applications — <file>**.

## Decisions

- Use `Gtk.Notebook` for conventional tabs rather than a view stack.
- Keep the file summary visible across all tabs; it is the context for every
  application list.
- Keep the About checks in the tab, not in a separate window. A tab can be
  replaced without managing another window lifecycle.
- Keep the project links enabled: they are known constants, unlike the
  application candidates that must be verified.
- Do not launch a browser from a test. The tab is inspected directly and the
  candidate checks are injected.

## Verification

- `make test` on 2026-10-22: all 27 test scripts passed.
- `tests/82-about-link` asserts:
  - the tab labels are Installed, Relevant, About;
  - the initial About page contains the version, GitHub repository, and labs
    project links;
  - clicking an application About action selects the About tab and replaces the
    page with the candidate links;
  - the candidate links are disabled before the injected checks and enabled
    after success;
  - no tooltip on the About control or candidate links;
  - no test launches a URI.
- The install Run test still passes.
- The installed copy was not updated, per the owner's manual-install preference.

## Commits

- `2ce512e` feat: put the chooser in Installed, Relevant, and About tabs
- `3dc2301` fix: title the chooser Discover Applications

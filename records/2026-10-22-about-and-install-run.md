# Record: About verification, installed-list filter, and install Run

## Outcome

The **About** link was verified twice. On the real desktop the chooser built 16
About links for the sample image recommendation set; every link had the label
"About" and an `https://` URI, the first resolved to the GNOME Loupe project
page, and the desktop reported `google-chrome.desktop` as the `https` handler.
In the sandbox the same test resolved the fixture AppStream page, launched the
fixture browser through `Gio.AppInfo.launch_default_for_uri`, and printed
`HTTPS-LAUNCH ok`.

The chooser's own desktop entry, `filetype-handler.desktop`, is no longer
discovered as an installed application, so "File Type Chooser" cannot appear in
the installed list or in recommendations.

The install dialog now has a **Run** button for every install hint. It starts
the package manager as an argument vector, disables the runnable buttons while
it works, streams stdout and stderr into a text view, and reports the exit
status. Flatpak installs under the user account; apt and snap use `pkexec` when
available and fail closed with `sudo -n` otherwise.

## Decisions

- Use AppStream as the first source for the About link, then vendor URL,
  Flathub, Snapcraft, and the distribution package page. A package path such as
  `/snap/bin/gimp` is reduced to `gimp` before building the package URL.
- Filter the chooser by its fixed desktop id in discovery, in `for_mime`, and in
  the visible-application list. Filtering at discovery is the primary fix; the
  other two are defence in depth.
- Test the Run button by replacing `install_argv` with `/bin/echo` inside the
  GTK test. This exercises the signal wiring, the output view, the streaming
  callbacks, and the completion status without installing software.
- Set `FILETYPE_INTEGRATION_REQUIRE_SANDBOX=1` in the test environment. The
  installer and uninstaller refuse when `HOME` is not under the temporary
  directory, so a leaked test environment cannot change the developer's
  desktop.

## Verification

- `make test` on 2026-10-22: all 24 test scripts passed.
- `82-about-link`: `ABOUT-LINKS 14`, `HTTPS-HANDLER test-browser.desktop`,
  `HTTPS-LAUNCH ok`, `RUN-BUTTONS 2`, `OUTPUT-VIEW ok`, `RUN-OUTPUT ok`.
- Real Xvfb check: `ABOUT-LINKS 16`, `ABOUT-EXISTS True`, first URI
  `https://apps.gnome.org/Loupe/`, `HTTPS-HANDLER google-chrome.desktop`.
- `70-handler-install` asserts the handler desktop id and "File Type Chooser"
  are absent from both installed and available application lists after install.
- The live desktop is clean: no handler entry, launcher, icon, manifest, or
  `mimeapps.list` change remains; `gio mime` reports the original defaults.

## Commits

- `2cdbb04` feat: omit the chooser from installed apps and add install Run

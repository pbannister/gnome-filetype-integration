# Record: Discover Applications title

## Outcome

The desktop handler is named **Discover Applications…**, matching the window's
purpose, instead of "File Type Chooser".

Changed:
- the `Name=` field of `filetype-handler.desktop`;
- `filetype handler install` and `uninstall` messages;
- the installer messages and comments;
- the README, feature behavior, site pages, and the handler test.

The handler id remains `filetype-handler.desktop`, so the manifest, MIME
defaults, and uninstall path are unchanged.

## Verification

- `make test` on 2026-10-22: all 27 test scripts passed.
- `tests/70-handler-install` checks the desktop entry's `Name=` and confirms the
  handler itself is still absent from the installed-application list.
- The installed copy has not been updated, per the owner's manual-install
  preference; `make install` applies the new name.

## Commits

- `23e9f8c` feat: rename the chooser to Discover Applications

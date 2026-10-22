# Record: orphaned chooser windows

## What happened

Five windows titled "Open with — quoted-fields.csv" were left on the desktop.
They could not be closed through the chooser's controls, and the process was
not visible from the agent's sandbox.

The cause was the shared GApplication identity. Every chooser used
`io.github.filetype.Chooser`, which is registered on the **session bus**, not on
a particular display. When another process with the same identity started — a
test under Xvfb, or another chooser — GLib treated it as a remote instance and
sent an activation signal to the existing process. The existing process's
`on_activate` rebuilt its startup window, so each activation added another
window for the original file. The process lived outside the agent's PID
namespace, which is why `ps` in the sandbox showed nothing.

## Fix (applied, verified)

- Each chooser process now uses a distinct application identity:
  `io.github.filetype.Chooser.p<pid>`. A test or another session can no longer
  remote-activate the user's window.
- `on_activate` reuses an existing window for the same path instead of building
  a duplicate.
- A window removes itself from the registry on `close-request`.
- **Escape** closes a window, the Close button remains, and a `quit` action with
  **Ctrl+Q** is registered.
- The GTK test now starts two chooser processes in parallel and requires both to
  build their own window, which would fail under the old shared identity.

## Old windows

The old process released its session-bus name during the repair. If a stale
window is still visible, the process can be identified and terminated from the
normal user session with:

```sh
pid=$(gdbus call --session --dest org.freedesktop.DBus \
    --object-path /org/freedesktop/DBus \
    --method org.freedesktop.DBus.GetConnectionUnixProcessID io.github.filetype.Chooser \
    | sed -n 's/.*uint32 \([0-9]*\).*/\1/p')
[ -n "$pid" ] && kill "$pid"
```

A lingering surface with no owning process requires a Shell restart or a
logout, not another change to this project.

## Verification

- `make test` on 2026-10-22: all 26 test scripts passed.
- `tests/80-gtk-chooser` runs two chooser processes in parallel under separate
  Xvfb displays and requires a built window from each.
- `tests/82-about-link` still builds the window, clicks About, and exercises the
  Run output path.
- The installed copy reports `2026-10-22-master-946552d (build 76)`.
- The old `io.github.filetype.Chooser` session-bus name is no longer owned.

## Commits

- `b8e5f22` fix: give each chooser its own window lifecycle
- `946552d` docs: note the chooser window controls

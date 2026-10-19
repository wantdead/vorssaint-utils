# OpenVPN Connect panel section

## Intent

Control OpenVPN Connect from the Vorssaint menu panel: see whether a tunnel is up, connect a saved profile, disconnect. The aim is to avoid opening the OpenVPN Connect window for the common case.

OpenVPN Connect stays installed and owns the tunnel. Vorssaint only sends it commands and reports the result.

## Goals

- A new VPN section in the menu panel, reorderable and hideable like the other sections.
- Status: connected or disconnected, with the active profile's name.
- Connect: pick one of the profiles saved in OpenVPN Connect and start it.
- Disconnect the active tunnel.
- A profile that needs a PIN shows a "waiting for PIN" state, plus a button that brings OpenVPN Connect to the front.

## Non-goals

- Importing, editing or removing profiles.
- Replacing OpenVPN Connect or running the Homebrew `openvpn` binary.
- Support for other VPN clients.

## Anti-goals

- Vorssaint must never read, store, log or type a PIN or password. A PIN is entered in OpenVPN Connect's own window. A design that passes the PIN through Vorssaint is a failure even if it works.
- When OpenVPN Connect cannot be controlled, the section must say so. It must not show a stale "connected" or fail silently.

## What was found about OpenVPN Connect (macOS)

Verified on the installed app:

- Executable: `/Applications/OpenVPN Connect/OpenVPN Connect.app/Contents/MacOS/OpenVPN Connect`.
- `--list-profiles` prints JSON with `id`, `name`, `host`, `type` per profile. This is documented in `--help`.
- `--connect-shortcut=<profile id>` starts a connection. It is not in `--help`; it appears in the app's bundled code. Running it started a connection that then asked for a PIN.
- `--disconnect-shortcut` is also undocumented. It ended the tunnel and the log wrote `EVENT: DISCONNECTED`.
- The log writes nothing while a PIN is pending, so the section must remember a connect it started. The log does not name the profile; the `CONNECTED` entry names the server host, which can be matched to a profile's `host`. See `docs/superpowers/plans/2026-10-19-openvpn-connect-section-spike.md`.
- No status command exists. The app writes connection events to `~/Library/Application Support/OpenVPN Connect/log/ovpn.log`, for example `EVENT: CONNECTED …`, `EVENT: CONNECTING`, `EVENT: GET_CONFIG`, `EVENT: ASSIGN_IP`. The tunnel appears as a `utun` interface.
- OpenVPN Connect does not show up in `scutil --nc list`, so the system VPN status API cannot be used.
- There is no command-line way to supply a PIN or private-key password at connect time. `--import-profile` accepts one at import only.
- A profile can need a PIN on every connect. The profile inspected had no username or password directive, so the PIN is most likely a key or token unlock. This is an inference.

## Decisions

Made with the maintainer:

- Placement: a new VPN section in the menu panel.
- PIN: left to OpenVPN Connect's window. The panel shows the waiting state and can raise that window.
- Status is read from OpenVPN Connect's log.
- If `--disconnect-shortcut` does not end the tunnel, stop during the spike and ask the maintainer before choosing any other disconnect method. Do not quit the app, kill processes, or script its UI on your own.

## Project facts

- Panel sections are cases in `MenuPanelView.swift`'s section switch, each gated by a per-section `@AppStorage` toggle declared in `Settings/MonitorPanelConfig.swift` (see `.network` and `monitorShowNetwork`). The VPN section follows the same pattern. No panel architecture change is expected.
- Vorssaint ships directly, signed with a Developer ID and notarized. No sandbox entitlements were found in the repo, so reading another app's Application Support folder is expected to work. Confirm it in the first spike.

## Calls made by the author

- "Connected" needs both a `CONNECTED` event in the log and a `utun` interface with an address. If they disagree, show disconnected.
- Status refreshes while the panel is open. No background polling when it is closed.
- If the log cannot show that a PIN is pending, show plain "connecting". The button that raises OpenVPN Connect appears in every connecting state. This overrides the "waiting for PIN" line in Done when.
- The active profile's name is shown only when it can be read reliably (from the log, or from the id Vorssaint started). Otherwise show status without a name.
- No minimum OpenVPN Connect version check. If a flag or the log wording stops working, show the "cannot control" state.

## First spike

Before building the section, run these against the real app and record the results in the plan:

- What `--connect-shortcut` and `--disconnect-shortcut` do when the app is not running, and when it is: whether they launch it, take focus, or start a second instance, and what exit code they return.
- Whether `--disconnect-shortcut` ends the tunnel.
- Whether the log names the active profile, by name or id.
- Whether more than one tunnel can be active.
- Whether Vorssaint can read the log file.

## Left to the builder

- How status is derived: log events, the `utun` interface, or both, and how to avoid a stale reading after the app restarts or the log rotates.
- How a "waiting for PIN" state is detected, if the log exposes it. If it cannot be detected reliably, a plain "connecting" state is acceptable.
- Whether the profile list is read through `--list-profiles` or the profiles folder.
- How to run the command-line calls safely: bounded runtime, no shell, and no effect when OpenVPN Connect is not installed. The repo already has `BoundedProcessRunner`.
- Section layout, settings entry, translations and tests, following the existing sections.
- Behaviour when OpenVPN Connect is not installed: hide the section, or show a short note.

## Risks

- Both control flags are undocumented and may change in an app update. The section needs a visible "cannot control OpenVPN Connect" state, and the code should isolate the flag names in one place.
- Log parsing depends on the app's wording. Keep it narrow and cover it with tests that use sample log lines.
- Starting a connection changes the user's network. It must only happen from an explicit click.

## Done when

- With OpenVPN Connect installed, the section lists the saved profiles and shows correct status for connected and disconnected, checked against the real app.
- Connect starts the chosen profile, and a PIN-protected profile reaches the connecting state, with the button that raises OpenVPN Connect, without Vorssaint handling the PIN.
- Disconnect ends the tunnel, confirmed against the real app.
- Without OpenVPN Connect, or when a flag stops working, the section shows a clear state and nothing crashes.
- Tests cover log parsing and profile-list parsing. The build and the existing test suite pass.

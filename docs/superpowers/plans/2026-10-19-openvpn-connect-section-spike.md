# OpenVPN Connect control spike results

Run against OpenVPN Connect 3 (core 3.11.3) on macOS. Hostnames and addresses are placeholders.

## Findings

- **Live log:** `~/Library/Application Support/OpenVPN Connect/log/ovpn.log`. `ovpn_full.log` in the same folder is an old archive and is not written to.
- **Log shape:** entries are separated by `⏎` (U+23CE), not reliably by newlines, and a line can hold two entries. Parse with a regex over the tail, not by line.
- **Event names seen:** `RESOLVE`, `WAIT`, `CONNECTING`, `GET_CONFIG`, `ASSIGN_IP`, `CONNECTED`, `RECONNECTING`, `PAUSE`, `RESUME`, `DISCONNECTED`, `EPKI_ERROR`, `TUN_ERROR`. A normal connect runs `RESOLVE`, `WAIT`, `CONNECTING`, `GET_CONFIG`, `ASSIGN_IP`, `CONNECTED`.
- **`--disconnect-shortcut` works.** It produced `EVENT: DISCONNECTED` and the tunnel ended.
- **`--connect-shortcut=<id>` works.** The log wrote nothing while the PIN was pending (about 9 seconds in the test). The first entry after the PIN was `RESOLVE`. So Vorssaint must remember it started a connect, because the log still shows the previous session's last event.
- **The log does not name the active profile.** `EVENT: CONNECTED` names the server host. `--list-profiles` returns a `host` per profile. Two of the three saved profiles share a host, so a name can be shown only when exactly one profile has that host.
- **`--list-profiles` JSON fields:** `host`, `id`, `name`, `server-override`, `type`, `username`. The output is a JSON array.
- **Other VPNs:** Tailscale and others also own addressed `utun` interfaces, so the interface must be the one the log names.

## Not measured

- Exit codes, focus behaviour, and behaviour when the app is not running. Checking them would drop the VPN again, so they are checked in plan Task 6, Step 5.
- Whether more than one tunnel can be active. OpenVPN Connect's window shows one connection at a time; assumed single.
- Whether Vorssaint can read the log. Checked in Task 6.

## Sample log (placeholders)

```
⏎[Oct 19, 2026, 21:09:36] Performance stats on disconnect:
⏎[Oct 19, 2026, 21:09:36] EVENT: DISCONNECTED ⏎[Oct 19, 2026, 21:09:45] OpenVPN core 3.11.3 mac arm64 64-bit built on Oct 24 2025 02:51:48
⏎[Oct 19, 2026, 21:09:45] EVENT: RESOLVE ⏎[Oct 19, 2026, 21:09:45] Contacting 192.0.2.10:1194 via TCP
⏎[Oct 19, 2026, 21:09:45] EVENT: WAIT ⏎[Oct 19, 2026, 21:09:46] EVENT: CONNECTING ⏎[Oct 19, 2026, 21:09:46] Creds: UsernameEmpty/PasswordEmpty
⏎[Oct 19, 2026, 21:09:46] EVENT: GET_CONFIG ⏎[Oct 19, 2026, 21:09:46] Sending PUSH_REQUEST to server...
⏎[Oct 19, 2026, 21:09:47] EVENT: ASSIGN_IP ⏎[Oct 19, 2026, 21:09:47] CAPTURED OPTIONS:
⏎[Oct 19, 2026, 21:09:47] Connected via utun7
⏎[Oct 19, 2026, 21:09:47] EVENT: CONNECTED vpn.example.com:1194 (192.0.2.10) via /TCP on utun7/198.51.100.4/ gw=[198.51.100.1/] mtu=1400⏎[Oct 19, 2026, 21:09:47] MacLifeCycle NET_STATE 1 status=ReachableViaWiFi flags=-R -------
```

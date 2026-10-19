# OpenVPN Connect panel section Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a VPN section to the menu panel that shows OpenVPN Connect's status and connects or disconnects a saved profile.

**Architecture:** A pure support file parses the app's `--list-profiles` JSON and its log, and turns them into a status. A small service runs the app's command-line flags through `BoundedProcessRunner`, reads the log tail, and polls only while the panel is open. A new `PanelSectionID.vpn` section, gated by a new opt-in `AppFeature.openVPN`, renders it.

**Tech Stack:** Swift, SwiftUI, the repo's own test harness (`./build.sh --test-suite=NAME`).

**Spec:** `docs/superpowers/specs/2026-10-19-openvpn-connect-section-design.md`

## Global Constraints

- Vorssaint never reads, stores, logs or types a PIN or password. The PIN is entered in OpenVPN Connect's own window.
- Control only through `/Applications/OpenVPN Connect/OpenVPN Connect.app/Contents/MacOS/OpenVPN Connect` with `--list-profiles`, `--connect-shortcut=<profile id>` and `--disconnect-shortcut`. No shell. Run through `BoundedProcessRunner.run` with a timeout and an output cap.
- Status is read from `~/Library/Application Support/OpenVPN Connect/log/ovpn.log`. Read only the last 65,536 bytes.
- "Connected" needs a `CONNECTED` event in the log and the interface the log names (`Connected via utunN`) to exist with an IPv4 address. Other VPNs also have addressed `utun` interfaces, so never test "any utun".
- Poll only while the panel is open. No work when the panel is closed or the feature is off.
- If `--disconnect-shortcut` does not end the tunnel, stop and ask the maintainer. Do not quit the app, kill processes, or script its UI.
- Every new source file starts with the repo's SPDX and copyright header. Update every locale in `AppLanguage.allCases`.
- The build finishes without warnings. No AI or tool attribution in commits or code.
- Commit messages: one short imperative sentence, no prefix, matching `git log`.

## Review Focus

- The log says `CONNECTED` but the named interface is gone (crash or stale log): status is disconnected. Task 2.
- Another VPN's `utun` has an address while OpenVPN is down: status is not connected. Task 2.
- The log is missing, empty, unreadable or has no events: a clear unavailable state, no crash. Tasks 2 and 4.
- `--list-profiles` prints nothing, junk, or JSON with extra text around it: an empty list, no crash. Task 2.
- A profile id that is not all digits never reaches the command line. Task 2.
- A very large or multi-session log: only the tail is read and the last event wins. Task 2.

---

### Task 1: Spike against the real app

The maintainer must be at the machine: this drops the VPN, and reconnecting asks for a PIN.

**Files:**
- Create: `docs/superpowers/plans/2026-10-19-openvpn-connect-section-spike.md` (results and sample log lines)

- [ ] **Step 1: Record the baseline.** Run `"<app>" --list-profiles` and save the JSON shape (field names only, no hosts). Save the last 30 lines of `ovpn.log` with hostnames and addresses replaced by placeholders.
- [ ] **Step 2: Run `--disconnect-shortcut` with the app open and connected.** Record the exit code, whether it took focus or opened a dialog, whether the tunnel ended (`ifconfig <utunN>`), and the log events it wrote. Expected: tunnel ends and the log shows a terminal event. Record that event's exact text.
- [ ] **Step 3: If the tunnel did not end, stop and ask the maintainer.** Do not continue to Task 2 until they answer.
- [ ] **Step 4: Run `--connect-shortcut=<id>`** with the app open and then with the app quit. Record: does it launch the app, take focus, start a second instance, and what exit code it returns. Have the maintainer enter the PIN and record the event sequence up to `CONNECTED`, including whether the log shows anything while the PIN is pending.
- [ ] **Step 5: Answer the remaining spike questions from the spec:** does the log name the active profile (by name or id), can more than one tunnel be active, and can Vorssaint read the log (run `tail -c 200` on it from a normal Vorssaint-signed build later, in Task 6).
- [ ] **Step 6: Commit the spike notes.** `git add docs/superpowers/plans/2026-10-19-openvpn-connect-section-spike.md && git commit -m "Record OpenVPN Connect control spike results"`

### Task 2: Support parsing and status rules

**Files:**
- Create: `Sources/Vorssaint/Services/OpenVPN/OpenVPNSupport.swift`
- Create: `Tests/OpenVPNTests.swift`
- Modify: `build.sh` (add the support file to `TEST_SOURCES`, next to `Services/Wallpaper/WallpaperSupport.swift`)
- Modify: `Tests/MetricsTests.swift` (register suite `"openvpn"` next to `"network"`)

**Interfaces:**
- Produces:
  - `struct OpenVPNProfile: Equatable, Identifiable { let id: String; let name: String; let host: String }`
  - `enum OpenVPNLogState: Equatable { case noEvents, inProgress, connected(interface: String?, host: String?), ended }`. In progress: `RESOLVE WAIT CONNECTING GET_CONFIG ASSIGN_IP RECONNECTING PAUSE RESUME`. Ended: `DISCONNECTED EPKI_ERROR TUN_ERROR`. Unknown event names are ignored. See the spike notes.
  - `enum OpenVPNUnavailableReason: Equatable { case appMissing, logUnreadable, commandFailed }`
  - `enum OpenVPNStatus: Equatable { case unavailable(OpenVPNUnavailableReason), disconnected, connecting, connected(profileName: String?) }`
  - `enum OpenVPNSupport` with:
    - `static let appExecutablePath: String`, `static let logTailBytes: Int`
    - `static func logURL(home: URL) -> URL`
    - `static func parseProfiles(_ output: Data) -> [OpenVPNProfile]`
    - `static func parseLogState(_ tail: String) -> OpenVPNLogState`
    - `static func lastEventMarker(_ tail: String) -> String?`: the timestamp and name of the last `EVENT:` entry, for example `"Oct 19, 2026, 21:09:36 DISCONNECTED"`
    - `static func resolveStatus(_ log: OpenVPNLogState, profiles: [OpenVPNProfile], interfaceHasAddress: (String) -> Bool) -> OpenVPNStatus`. The profile name is set only when exactly one profile has the host from the `CONNECTED` entry.
    - `static func connectArguments(profileID: String) -> [String]?`
    - `static let disconnectArguments: [String]`

- [ ] **Step 1: Write failing tests in `OpenVPNTests.swift`** (enum `OpenVPNTests` with `static func run(_ suite: TestSuite)`), using the sample lines saved in Task 1:
  - `parseProfiles` on the real JSON shape returns the ids, names and hosts in order; on `""`, on `"garbage"`, and on JSON wrapped in leading and trailing text returns `[]`, `[]`, and the profiles.
  - `parseLogState` (using the sample log in the spike notes, where entries are separated by `⏎` and a line can hold two entries) returns `.connected(interface: "utun7", host: "vpn.example.com")` for a tail ending in the `CONNECTED` entry; `.inProgress` for a tail ending in `EVENT: GET_CONFIG`; `.ended` for tails ending in `DISCONNECTED`, `EPKI_ERROR` or `TUN_ERROR`; `.noEvents` for `""`; unknown event names are skipped; and the last event wins when the tail holds an older `CONNECTED` followed by a later in-progress event.
  - `lastEventMarker` returns `"Oct 19, 2026, 21:09:36 DISCONNECTED"` for the sample log cut after that entry, and `nil` for `""`.
  - `resolveStatus(.connected(interface: "utun7", host: h), profiles: ps, interfaceHasAddress: { _ in false })` is `.disconnected`; with `{ $0 == "utun7" }` it is `.connected(profileName:)`; with `interface: nil` it is `.disconnected`. The name is the profile's when exactly one profile has host `h`, and `nil` when two do or none does.
  - `connectArguments(profileID: "1747746310902")` is `["--connect-shortcut=1747746310902"]`; `"12; rm -rf"`, `""` and `"abc"` return `nil`.
  - `disconnectArguments == ["--disconnect-shortcut"]`.
- [ ] **Step 2: Run `./build.sh --test-suite=openvpn`.** Expected: FAIL to compile, `OpenVPNSupport` not defined.
- [ ] **Step 3: Implement `OpenVPNSupport.swift`** with the signatures above. `parseProfiles` takes the text between the first `[` and the last `]` and decodes `id` and `name`; any failure returns `[]`. `parseLogState` scans lines from the end for the last `EVENT: <NAME>`. The interface comes from the nearest earlier `Connected via <name>` line.
- [ ] **Step 4: Run `./build.sh --test-suite=openvpn`.** Expected: PASS.
- [ ] **Step 5: Commit.** `git add Sources/Vorssaint/Services/OpenVPN/OpenVPNSupport.swift Tests/OpenVPNTests.swift Tests/MetricsTests.swift build.sh && git commit -m "Parse OpenVPN Connect profiles and log state"`

### Task 3: Strings for every locale

**Files:**
- Create: `Sources/Vorssaint/Core/OpenVPNStrings.swift`
- Modify: `build.sh` (add it to `TEST_SOURCES` next to `Core/WallpaperStrings.swift`)
- Test: `Tests/OpenVPNTests.swift`

**Interfaces:**
- Produces: `struct OpenVPNFeatureStrings` with `String` fields `pageTitle, hubDescription, panelDescription, statusConnected, statusConnecting, statusDisconnected, connect, disconnect, openApp, pinHint, profile, appMissing, cannotControl, noProfiles`, and `extension FeatureStrings { static func openVPN(_ language: AppLanguage) -> OpenVPNFeatureStrings }`. Follow the layout of `Core/WallpaperStrings.swift`.

- [ ] **Step 1: Write the failing test** in `OpenVPNTests.swift`: for each `AppLanguage.allCases`, every field of `FeatureStrings.openVPN(language)` is non-empty, and `pinHint` is not equal to the English text in any language other than `.enUS`.
- [ ] **Step 2: Run `./build.sh --test-suite=openvpn`.** Expected: FAIL, `FeatureStrings.openVPN` not defined.
- [ ] **Step 3: Implement `OpenVPNStrings.swift`.** `pinHint` reads like "Enter the PIN in OpenVPN Connect". Keep the product name `OpenVPN Connect` untranslated.
- [ ] **Step 4: Run `./build.sh --test-suite=openvpn`.** Expected: PASS.
- [ ] **Step 5: Commit.** `git commit -am "Add OpenVPN section strings for every locale"` (after `git add` of the new file).

### Task 4: Feature, defaults and panel section registration

**Files:**
- Modify: `Sources/Vorssaint/Core/FeatureCatalog.swift`, `Sources/Vorssaint/Core/Defaults.swift`, `Sources/Vorssaint/UI/MenuPanel/PanelLayout.swift`, `Sources/Vorssaint/UI/Settings/PanelLayoutEditor.swift`, `Sources/Vorssaint/UI/Settings/FeatureHubSettings.swift`, `Sources/Vorssaint/UI/Settings/SettingsDirectory.swift`, `Sources/Vorssaint/UI/Settings/FeatureVisibilitySupport.swift`
- Test: `Tests/FeatureCatalogTests.swift`

**Interfaces:**
- Produces: `AppFeature.openVPN` (group `.tools`, symbol `"lock.shield"`, `installedByDefault == false`, no permissions); `PanelSectionID.vpn` (symbol `"lock.shield"`, `featureGate [.openVPN]`, `visibilityKey DefaultsKey.panelShowVPN`); `DefaultsKey.panelShowVPN = "panelShowVPN"` registered as `true`.

- [ ] **Step 1: Update `Tests/FeatureCatalogTests.swift`.** Add `"openVPN"` to the raw-value list near line 402 and add assertions that `AppFeature.openVPN.installedByDefault == false`, `AppFeature.openVPN.group == .tools`, and `SettingsBackupSupport.exportKeys().contains(DefaultsKey.panelShowVPN)`.
- [ ] **Step 2: Run `./build.sh --test-suite=feature-catalog`** (use `./build.sh --list-tests` for the exact suite name). Expected: FAIL.
- [ ] **Step 3: Add the case and key.** Mirror every `.portManager` and `.wallpaper` site in the files above. The compiler flags each exhaustive switch missed. Settings destination: same as `.portManager`. Hub and panel descriptions come from `FeatureStrings.openVPN(language)`.
- [ ] **Step 4: Run the feature-catalog and `openvpn` suites.** Expected: PASS. Run `./build.sh` once to confirm the app still compiles; the new `.vpn` case in `MenuPanelView` is wired in Task 6, so temporarily return `EmptyView()` for it if the switch is the only error.
- [ ] **Step 5: Commit.** `git commit -am "Register the OpenVPN Connect feature and panel section"`

### Task 5: Service

**Files:**
- Create: `Sources/Vorssaint/Services/OpenVPN/OpenVPNService.swift`
- Test: `Tests/OpenVPNTests.swift`

**Interfaces:**
- Consumes: everything from Task 2; `BoundedProcessRunner.run(_:_:timeout:maxOutputBytes:environment:cancellation:)`.
- Produces: `final class OpenVPNService: ObservableObject` (follow `NetworkAddressService`'s concurrency pattern) with
  - `init(runCommand: @escaping ([String]) -> BoundedProcessRunner.Result, readLogTail: @escaping () -> String?, interfaceHasAddress: @escaping (String) -> Bool, appInstalled: @escaping () -> Bool)` and a `static let shared` built from live closures
  - `@Published private(set) var status: OpenVPNStatus`, `@Published private(set) var profiles: [OpenVPNProfile]`
  - `func panelDidAppear()` and `func panelDidDisappear()`, which start and stop a 2-second poll
  - `func refresh()`, `func connect(profileID: String)`, `func disconnect()`, `func raiseApp()`

- [ ] **Step 1: Write failing tests** with fake closures:
  - app not installed → `.unavailable(.appMissing)`, and `runCommand` is never called.
  - `readLogTail` returns `nil` → `.unavailable(.logUnreadable)`.
  - `connect(profileID: "abc")` never calls `runCommand`.
  - `connect(profileID: "1747746310902")` passes `["--connect-shortcut=1747746310902"]`; a non-zero or timed-out result sets `.unavailable(.commandFailed)`.
  - `disconnect()` passes `["--disconnect-shortcut"]`.
  - a log tail ending `CONNECTED` with the named interface present gives `.connected`; absent gives `.disconnected`.
  - after `panelDidDisappear()` no further `readLogTail` calls happen.
  - the log is silent while a PIN is pending: after `connect(profileID:)` with a tail whose last event is `DISCONNECTED`, status is `.connecting`; once the tail's `lastEventMarker` changes, status follows the log; with no change, `.connecting` ends after 120 seconds (use an injectable clock) and returns to `.disconnected`.
  - `OpenVPNService.init` gains `now: @escaping () -> Date` for that timeout.
- [ ] **Step 2: Run `./build.sh --test-suite=openvpn`.** Expected: FAIL.
- [ ] **Step 3: Implement the service.** Run commands off the main thread with timeout 10 s and output cap 64 KB. `readLogTail` seeks to the last `logTailBytes` of the file. The live `interfaceHasAddress` uses `getifaddrs` and matches the exact interface name with an `AF_INET` address. `raiseApp()` opens OpenVPN Connect with `NSWorkspace`. Add the file to `TEST_SOURCES` in `build.sh`.
- [ ] **Step 4: Run `./build.sh --test-suite=openvpn`.** Expected: PASS.
- [ ] **Step 5: Commit.** `git add Sources/Vorssaint/Services/OpenVPN/OpenVPNService.swift Tests/OpenVPNTests.swift build.sh && git commit -m "Add the OpenVPN Connect control service"`

### Task 6: Panel section view

**Files:**
- Create: `Sources/Vorssaint/UI/MenuPanel/VPNSection.swift`
- Modify: `Sources/Vorssaint/UI/MenuPanel/MenuPanelView.swift` (add `@AppStorage(DefaultsKey.panelShowVPN) private var showVPN = true` near line 87, `case .vpn: if showVPN { VPNSection(collapsible: collapsible) }` in the section switch, and `showVPN` in the tuple in `isSectionVisible`)

**Interfaces:**
- Consumes: `OpenVPNService.shared`, `FeatureStrings.openVPN`, `PanelSection(.vpn, title:collapsible:...)` as used by `NetworkSection`.
- Produces: `struct VPNSection: View { var collapsible = true }`.

- [ ] **Step 1: Build the view.** Header row with status dot and text (`statusConnected` / `statusConnecting` / `statusDisconnected`). A profile picker listing `service.profiles` by name. One button: `connect` when disconnected, `disconnect` when connected, disabled while connecting. While connecting, show `pinHint` and an `openApp` button that calls `raiseApp()`. For `.unavailable(.appMissing)` show `appMissing`; for the other reasons show `cannotControl`. If `profiles` is empty and the app is present, show `noProfiles`. Call `panelDidAppear()` in `.onAppear` and `panelDidDisappear()` in `.onDisappear`.
- [ ] **Step 2: Wire it into `MenuPanelView`** as described and remove any temporary `EmptyView()` from Task 4.
- [ ] **Step 3: Build.** Run `./build.sh` and expect no errors or warnings.
- [ ] **Step 4: Run the app's selftest.** `./build/VorssaintDeveloper --selftest`. Expected: pass.
- [ ] **Step 5: Check on the real app with the maintainer present.** Enable the feature in the Features page. Confirm: the section lists the saved profiles; status matches the real state; Connect starts a connection and the section shows connecting and the PIN hint; after the PIN, it shows connected; Disconnect ends the tunnel; quitting OpenVPN Connect shows a clear state. Confirm Vorssaint can read the log file. Record what was checked and on which macOS version.
- [ ] **Step 6: Commit.** `git add Sources/Vorssaint/UI/MenuPanel/VPNSection.swift Sources/Vorssaint/UI/MenuPanel/MenuPanelView.swift && git commit -m "Add the VPN panel section"`

### Task 7: Docs and full verification

**Files:**
- Modify: `README.md` (feature list), `CHANGELOG.md` (unreleased entry, following its existing format), `docs/PRIVACY.md` (one line: reads OpenVPN Connect's connection log on this Mac; the PIN is never read or stored)

- [ ] **Step 1: Update the three docs.** Keep each addition to a sentence or two. Mention that the feature controls OpenVPN Connect through its undocumented flags and may stop working after an app update.
- [ ] **Step 2: Run the full checks.** `./build.sh --test` expected all suites pass; `./build.sh` expected no warnings; `./build/VorssaintDeveloper --selftest` expected pass.
- [ ] **Step 3: Commit.** `git commit -am "Document the OpenVPN Connect section"`

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Vorssaint is a native macOS menu-bar utility suite (Swift, AppKit + SwiftUI, macOS 14+, Apple Silicon, GPL-3.0-or-later). This checkout is on `local/omniwm`, a personal fork of `main` that adds an OmniWM workspace strip to the Dynamic Island ("notch") and an OpenVPN Connect panel section. Upstream is `vorssaint/vorssaint-utils`.

## Build and test

There is no Xcode project and no package dependencies. `build.sh` calls `swiftc` directly, assembles and signs the `.app`. `Package.swift` exists only for editor indexing; `swift build` does not produce a working app.

```sh
./build.sh --dev                      # Developer variant (own bundle id, coexists with the official app)
./build/VorssaintDeveloper --selftest # runtime health check; run after any app/UI/resource change
./build.sh --dev --install            # install + launch the Developer app
./build.sh                            # optimized release-style build (what CI runs)
./build/Vorssaint --selftest          # selftest for the plain build

./build.sh --test                     # all tests
./build.sh --list-tests               # list suite names
./build.sh --test-suite=NAME          # one suite, e.g. --test-suite=notch
```

- Builds must finish without warnings.
- `build.sh` prefers the macOS 26 SDK; the 27 SDK breaks SwiftUI property wrappers under the Command Line Tools. CI also builds with Swift 6.0.3 / Xcode 16.2, so avoid newer-only language features.
- Local signing identity: `./Tools/setup-signing.sh` (auto-run on install builds). Keep it stable; ad-hoc rebuilds orphan Accessibility / Screen Recording grants. Each signing build asks once for keychain access: Allow, not Always Allow.
- Sensor work: attach `./build/Vorssaint --sensors` output and the Mac model.

### Tests are not compiled against the app

`--test` compiles an explicit list, `TEST_SOURCES` in `build.sh`, plus `Tests/*.swift` and `build/generated-tests/*.swift` into a separate executable (`VorssaintTests`). Consequences:

- **A new production file under test must be added to `TEST_SOURCES`**, or tests cannot see it. Keep tested logic in view-free `*Support.swift` / `*Strings.swift` files so it can be listed without dragging in AppKit views.
- Passing tests do not prove the app compiles. Run `./build.sh --dev` too.
- `Tests/generate_sources.py` extracts selected production method bodies verbatim into generated test sources. It fails closed if a method moves, is renamed or changes indentation, so edits to those methods can break the test build with a "Expected one declaration" error.
- `Tests/*.sh` and `PreferenceCleanupTests` run only in a full `--test` run, not with `--test-suite`. Tests that use `UserDefaults` suites leave plists in `~/Library/Preferences`; the script sweeps them, and `PreferenceNamespaceTests` scans test files against the known namespaces.
- `Tests/MetricsTests.swift` is the runner and suite registry: `("name", { FooTests.run(suite) })`. A new test type must be registered there or it never runs. `TestSuite.run` fails any test that executes zero assertions; an unknown or empty `--test-suite` is an error.

## Architecture

Single executable target `Sources/Vorssaint`, laid out by role (see CONTRIBUTING.md):

- `App/` lifecycle, status item, menu-bar rendering.
- `Core/` shared catalogs, preferences (`Defaults.swift`), localization, settings backup.
- `Services/<Feature>/` behavior, one folder per feature.
- `UI/` SwiftUI/AppKit views (`Settings`, `MenuPanel`, `Notch`, ...).
- `Support/` `SelfTest.swift` and diagnostic probes.
- Other targets: `Sources/FanControlHelper` (privileged XPC helper, built and self-tested by `build.sh`), `Sources/NowPlayingAdapter` (dylib loaded by `/usr/bin/perl` to read Now Playing; `Resources/now-playing.pl`), `HIDEventSystem` and `VMStatisticsCompat` (C module shims).

### Feature catalog drives everything

`Core/FeatureCatalog.swift` defines `AppFeature` (a case per feature, grouped by `FeatureGroup`), and `App/FeatureRuntime.swift` binds each case to its live singleton through closures. A feature can be uninstalled in the Features hub: it then vanishes from Settings, the menu panel and the menu bar, and its service never instantiates on next launch. Consequences when adding or changing a feature:

- Raw values are persisted in the availability key. Add cases, never rename them. Update the expected-case lists in `Tests/FeatureCatalogTests.swift`.
- Every entry point (hotkey, menu item, URL handler, settings page) must check availability and permissions. Background work must stop when the feature is disabled.
- Preferences must participate in settings backup (`Core/SettingsBackupSupport.swift`), or carry an explicit exclusion if machine-specific or private.

### Localization

Strings are Swift, not `.strings` files. Each feature has a `Core/<Feature>Strings.swift` struct with a `switch language` factory (`FeatureStrings.omniWM(_:)` is the pattern). Every case of `AppLanguage` (`Core/Localization.swift`, 15+ locales) must be filled in, including feature-specific catalogs; coverage tests fail otherwise. Only `Resources/*.lproj/InfoPlist.strings` (permission prompts) are real `.strings` files. A new language also needs locale registration and localized permission prompts.

New source files keep the SPDX + copyright header:

```swift
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
```

## Fork specifics (`local/omniwm`)

- Take upstream changes with `git pull upstream main` (a merge, not a rebase; the `upstream` remote is already set). Commit or stash local changes first. After the pull, run the `notch` suite, the selftest and a Developer build. `./Tools/update-local.sh` does the same from `origin/main` with these checks built in, but pulling `upstream` directly is the usual route.
- Fork code: `Services/Notch/OmniWMWorkspace{Service,Support}.swift`, `UI/Notch/OmniWMWorkspaceBarView.swift`, `UI/Settings/OmniWMSettings.swift`, `Core/OmniWMStrings.swift` (OmniWM IPC via `omniwmctl`). Keep fork changes in separate files where possible so upstream merges stay clean.
- OpenVPN Connect section is in progress: `Services/OpenVPN/OpenVPNSupport.swift`, `Core/OpenVPNStrings.swift`. Design and spike findings are in `docs/superpowers/specs/` and `docs/superpowers/plans/`. Hard rule from the design: Vorssaint must never read, store, log or type a PIN or password; when OpenVPN Connect cannot be controlled the section must say so rather than show stale state.
- The user has an external display only sometimes; check island/OmniWM changes on both.

## Contribution conventions

- PR title: `type(scope): lowercase imperative phrase`; reuse an existing scope.
- Reference issues with `Refs #123`, one per line. Never `Closes` / `Fixes` (the fix-status workflow closes issues after a stable release ships the fix).
- Do not bump versions or edit `CHANGELOG.md`; the maintainer does.
- Pushing, merging or tagging is not a release. Releases need an explicit decision and a signed tag, and run through `.github/workflows/release.yml`.
- For window, permission or hardware behavior, say what was verified on which Mac/macOS version and what remains untested. Compiling is not evidence an interaction works.
- `AGENTS.md` is gitignored for local-only notes.

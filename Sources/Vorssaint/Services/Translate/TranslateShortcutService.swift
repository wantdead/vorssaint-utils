// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// The global shortcut that opens the island on its Translate page.
final class TranslateShortcutService: ObservableObject {
    static let shared = TranslateShortcutService()

    @Published private(set) var shortcutRegistrationFailed = false
    private let hotkey = QuickToolHotkey(id: 82)

    private init() {
        hotkey.onPress = { [weak self] in self?.pressed() }
    }

    func syncWithPreferences() {
        let enabled = NotchSupport.routesTranslate()
            && UserDefaults.standard.bool(forKey: DefaultsKey.translateShortcutEnabled)
        let shortcut = GlobalShortcut.saved(for: DefaultsKey.translateShortcut,
                                            fallback: .translateDefault)
        shortcutRegistrationFailed = !hotkey.sync(enabled: enabled, shortcut: shortcut,
                                                  storageKey: DefaultsKey.translateShortcut)
    }

    func suspend() {
        hotkey.unregister()
    }

    private func pressed() {
        guard AppFeature.translate.isAvailable else { return }
        NotchService.shared.showTranslate(toggle: true)
    }
}

extension NotchService {
    /// Opens the island on Translate; a second press from that page closes it.
    /// Returns false when the island cannot show the page.
    @discardableResult
    func showTranslate(toggle: Bool = false) -> Bool {
        guard NotchSupport.routesTranslate(), acceptsUserInteraction else { return false }
        if toggle, expanded, selected == .translate, !showingAppPanel, !showingSections,
           !showingCommandBar, selectedMetric == nil {
            collapse()
        } else {
            open(.translate)
        }
        return true
    }
}

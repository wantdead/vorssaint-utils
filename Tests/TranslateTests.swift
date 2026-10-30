// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum TranslateTests {
    static func run(_ suite: TestSuite) {
        suite.expect(TranslateDirection.detect("Привет, как дела?") == .russianToEnglish,
                     "Russian text translates to English")
        suite.expect(TranslateDirection.detect("Where is the station?") == .englishToRussian,
                     "English text translates to Russian")
        suite.expect(TranslateDirection.detect("") == nil
                     && TranslateDirection.detect("  \n ") == nil,
                     "empty and whitespace-only text has no direction")
        suite.expect(TranslateDirection.detect("42 😀") == .englishToRussian,
                     "text without a language goes to Russian like any non-Russian text")
        suite.expect(TranslateDirection.detect("Привет, мне нужен backup сегодня вечером") == .russianToEnglish,
                     "mostly Russian text with an English word keeps the Russian direction")
        suite.expect(TranslateDirection.detect("Please send the report to Иван") == .englishToRussian,
                     "mostly English text with a Russian name keeps the English direction")
        suite.expect(TranslateDirection.detect("Привіт, як справи?") == .englishToRussian,
                     "Ukrainian text is not treated as Russian")
        suite.expect(TranslateDirection.russianToEnglish.swapped == .englishToRussian
                     && TranslateDirection.englishToRussian.swapped == .russianToEnglish,
                     "swapping flips the direction both ways")
        suite.expect(TranslateAvailability.isSupported(
                        operatingSystem: OperatingSystemVersion(majorVersion: 14, minorVersion: 7, patchVersion: 0)) == false,
                     "translation is unavailable on macOS 14")
        suite.expect(TranslateAvailability.isSupported(
                        operatingSystem: OperatingSystemVersion(majorVersion: 15, minorVersion: 0, patchVersion: 0)),
                     "translation is available from macOS 15")
        MainActor.assumeIsolated { runService(suite) }
        runFeature(suite)
        runCommandBar(suite)
    }

    private static func runCommandBar(_ suite: TestSuite) {
        suite.expect(CommandBarTranslate.text(in: "tr привет", isAvailable: true) == "привет",
                     "the short keyword hands over the text after it")
        suite.expect(CommandBarTranslate.text(in: "Translate hello world", isAvailable: true) == "hello world",
                     "the long keyword works in any case and keeps inner spaces")
        suite.expect(CommandBarTranslate.text(in: "  tr   привет  ", isAvailable: true) == "привет",
                     "spaces around the query and after the keyword are trimmed")
        suite.expect(CommandBarTranslate.text(in: "tr", isAvailable: true) == nil
                     && CommandBarTranslate.text(in: "tr   ", isAvailable: true) == nil
                     && CommandBarTranslate.text(in: "translate", isAvailable: true) == nil,
                     "a keyword with no text is an ordinary query")
        suite.expect(CommandBarTranslate.text(in: "track list", isAvailable: true) == nil
                     && CommandBarTranslate.text(in: "translator app", isAvailable: true) == nil
                     && CommandBarTranslate.text(in: "trello", isAvailable: true) == nil,
                     "words that only start with the keyword are ordinary queries")
        suite.expect(CommandBarTranslate.text(in: "tr привет", isAvailable: false) == nil,
                     "a query with the keyword is ordinary when translate is unavailable")
    }

    private static func runFeature(_ suite: TestSuite) {
        let domain = "com.vorssaint.tests.translate-feature"
        let defaults = UserDefaults(suiteName: domain)!
        defaults.removePersistentDomain(forName: domain)
        defer { defaults.removePersistentDomain(forName: domain) }
        let macOS14 = OperatingSystemVersion(majorVersion: 14, minorVersion: 7, patchVersion: 0)
        let macOS15 = OperatingSystemVersion(majorVersion: 15, minorVersion: 0, patchVersion: 0)
        let key = AppFeature.translate.availabilityKey

        defaults.set(true, forKey: key)
        suite.expect(AppFeature.translate.isAvailable(in: defaults, operatingSystem: macOS15),
                     "translate is available on macOS 15 when it is switched on")
        suite.expect(!AppFeature.translate.isAvailable(in: defaults, operatingSystem: macOS14),
                     "translate stays unavailable on macOS 14 even when switched on")
        defaults.set(false, forKey: key)
        suite.expect(!AppFeature.translate.isAvailable(in: defaults, operatingSystem: macOS15),
                     "translate is unavailable on macOS 15 when it is switched off")
        suite.expect(!NotchModule.translate.isAvailable(in: defaults),
                     "the island page is unavailable when the feature is off")
        defaults.set(true, forKey: key)
        suite.expect(NotchModule.translate.isAvailable(in: defaults)
                     == AppFeature.translate.isAvailable(in: defaults),
                     "the island page follows the feature's availability")

        suite.expect(Defaults.registeredDefaults[DefaultsKey.translateShortcutEnabled] as? Bool == false,
                     "the translate shortcut ships off like the other quick tools")
        suite.expect(Defaults.registeredDefaults[DefaultsKey.translateShortcut] as? String
                     == "control+option+command:5",
                     "the default translate shortcut is control option command G")
        suite.expect(GlobalShortcutRole.translate.requiredEnableKeys
                     == [DefaultsKey.notchEnabled, DefaultsKey.translateShortcutEnabled]
                     && GlobalShortcutRole.translate.feature == .translate,
                     "the translate shortcut needs the island, its own toggle and the feature")
        suite.expect(SettingsBackupSupport.exportKeys().isSuperset(of: [DefaultsKey.translateShortcut,
                                                                         DefaultsKey.translateShortcutEnabled]),
                     "the translate shortcut travels with the settings backup")
        suite.expect(GlobalShortcutRole.conflict(for: .translateDefault, excluding: .translate,
                                                 includeInactive: true) == nil,
                     "the default translate shortcut collides with no other role")
        defaults.set(true, forKey: DefaultsKey.notchEnabled)
        defaults.set(true, forKey: AppFeature.notch.availabilityKey)
        suite.expect(NotchSupport.routesTranslate(in: defaults),
                     "translate routes through the island while its page is on")
        defaults.set(NotchModule.translate.rawValue, forKey: DefaultsKey.notchHiddenModules)
        suite.expect(!NotchSupport.routesTranslate(in: defaults),
                     "a hidden island page cannot be opened by the shortcut or the command bar")
        defaults.set(false, forKey: DefaultsKey.notchEnabled)
        defaults.removeObject(forKey: DefaultsKey.notchHiddenModules)
        suite.expect(!NotchSupport.routesTranslate(in: defaults),
                     "translate does not route anywhere while the island is off")
        suite.expect(Set(NotchModule.allCases.map(\.shortcutKey)).count == NotchModule.allCases.count,
                     "every island page keeps its own shortcut key")
        suite.expect(AppLanguage.allCases.allSatisfy { language in
            let strings = FeatureStrings.translate(language)
            return [strings.pageTitle, strings.hubDescription, strings.placeholder, strings.swapHint,
                    strings.copyHint, strings.downloadNeeded, strings.failed, strings.unavailable]
                .allSatisfy { !$0.isEmpty }
        }, "every language has all the translate strings")
    }

    @MainActor
    private final class FakeBackend: TranslateBackend {
        var calls: [String] = []
        var pending: [CheckedContinuation<String, Error>] = []

        func translate(_ text: String, direction: TranslateDirection) async throws -> String {
            calls.append(text)
            return try await withCheckedThrowingContinuation { pending.append($0) }
        }

        func finish(_ index: Int, with result: Result<String, Error>) {
            pending[index].resume(with: result)
        }
    }

    private static func spin(timeout: TimeInterval = 2, until condition: () -> Bool) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while !condition() && Date() < end {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        return condition()
    }

    @MainActor
    private static func runService(_ suite: TestSuite) {
        let backend = FakeBackend()
        let service = TranslateService(backend: backend, isSupported: { true })

        service.translate("   \n")
        suite.expect(service.state == .idle && backend.calls.isEmpty,
                     "whitespace-only input makes no request")

        service.translate("привет")
        suite.expect(spin { backend.pending.count == 1 } && service.state == .translating,
                     "a request shows the translating state until the backend answers")
        backend.finish(0, with: .success("hello"))
        suite.expect(spin { service.state == .result("hello") },
                     "the backend answer becomes the result")

        service.translate("")
        suite.expect(service.state == .idle,
                     "clearing the input clears the result")

        service.translate("one")
        suite.expect(spin { backend.pending.count == 2 }, "the first of two requests reaches the backend")
        service.translate("two")
        suite.expect(spin { backend.pending.count == 3 }, "the second of two requests reaches the backend")
        backend.finish(2, with: .success("two!"))
        suite.expect(spin { service.state == .result("two!") }, "the newest request shows its result")
        backend.finish(1, with: .success("one!"))
        _ = spin(timeout: 0.2) { false }
        suite.expect(service.state == .result("two!"),
                     "an older request that finishes late does not replace a newer result")

        service.translate("missing")
        suite.expect(spin { backend.pending.count == 4 }, "the request for a missing pack reaches the backend")
        backend.finish(3, with: .failure(TranslateBackendError.languagePackMissing("ru")))
        suite.expect(spin { service.state == .needsLanguagePack("ru") },
                     "a missing language pack is reported by name, not as an empty result")

        service.translate("broken")
        suite.expect(spin { backend.pending.count == 5 }, "the failing request reaches the backend")
        struct Boom: Error {}
        backend.finish(4, with: .failure(Boom()))
        suite.expect(spin { service.state == .failed },
                     "any other backend error is a visible failure")

        let calls = backend.calls.count
        let unsupported = TranslateService(backend: backend, isSupported: { false })
        unsupported.translate("hello")
        suite.expect(unsupported.state == .unavailable && backend.calls.count == calls,
                     "an unsupported system reports unavailable and makes no request")
    }
}

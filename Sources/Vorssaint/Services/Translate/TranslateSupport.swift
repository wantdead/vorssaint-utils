// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation
import NaturalLanguage

/// The two ways text can go. The direction follows the input: Russian goes to
/// English, everything else goes to Russian.
enum TranslateDirection: Equatable {
    case russianToEnglish, englishToRussian

    var source: Locale.Language {
        switch self {
        case .russianToEnglish: return Locale.Language(identifier: "ru")
        case .englishToRussian: return Locale.Language(identifier: "en")
        }
    }

    var target: Locale.Language {
        switch self {
        case .russianToEnglish: return Locale.Language(identifier: "en")
        case .englishToRussian: return Locale.Language(identifier: "ru")
        }
    }

    var swapped: TranslateDirection {
        switch self {
        case .russianToEnglish: return .englishToRussian
        case .englishToRussian: return .russianToEnglish
        }
    }

    /// Nil for empty or whitespace-only text, which has nothing to translate.
    /// The recognizer runs on the Mac and sees the whole text, so a mostly
    /// Russian sentence with an English word stays Russian.
    static func detect(_ text: String) -> TranslateDirection? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return NLLanguageRecognizer.dominantLanguage(for: text) == .russian
            ? .russianToEnglish : .englishToRussian
    }
}

enum TranslateState: Equatable {
    case idle
    case translating
    case result(String)
    /// The language pack for this language code is not installed on the Mac.
    case needsLanguagePack(String)
    case unavailable
    case failed
}

enum TranslateBackendError: Error, Equatable {
    case languagePackMissing(String)
    /// No view is on screen to run the translation, so nothing can answer.
    case noHost
}

/// Whatever turns text into a translation, on the Mac. Kept apart from the
/// service so the service's decisions run without Apple's framework.
@MainActor
protocol TranslateBackend: AnyObject {
    func translate(_ text: String, direction: TranslateDirection) async throws -> String
}

/// Apple's on-device Translation arrives with macOS 15. Older systems get no
/// translate surface at all.
enum TranslateAvailability {
    static func isSupported(
        operatingSystem: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion
    ) -> Bool {
        operatingSystem.majorVersion >= 15
    }
}

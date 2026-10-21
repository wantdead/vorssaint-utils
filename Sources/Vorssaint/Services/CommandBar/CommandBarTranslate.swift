// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Combine
import Foundation

/// The bar's translate command: `tr` or `translate`, then the text. Any other
/// query, including words that merely start with the keyword, is searched as
/// usual.
enum CommandBarTranslate {
    private static let keywords = ["translate", "tr"]

    static func text(in query: String, isAvailable: Bool = AppFeature.translate.isAvailable) -> String? {
        guard isAvailable else { return nil }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let folded = trimmed.lowercased()
        for keyword in keywords where folded.hasPrefix(keyword) {
            let rest = trimmed.dropFirst(keyword.count)
            guard rest.first?.isWhitespace == true else { continue }
            let text = rest.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        }
        return nil
    }
}

/// Feeds the typed text to the translation service once typing pauses, and
/// says when an answer lands so the bar can redraw its rows. Nothing runs
/// until a query asks for it.
@MainActor
final class CommandBarTranslation {
    var onResult: () -> Void = {}
    private let service: TranslateService
    private var text: String?
    private var requested = false
    private var pending: Task<Void, Never>?
    private var observation: AnyCancellable?

    init(service: TranslateService) {
        self.service = service
        observation = service.$state.dropFirst().sink { [weak self] _ in self?.onResult() }
    }

    func request(_ text: String) {
        guard self.text != text else { return }
        self.text = text
        requested = false
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled, let self, self.text == text else { return }
            self.requested = true
            self.service.translate(text)
        }
    }

    /// What the row for `text` shows: waiting until the request has gone out.
    func state(for text: String) -> TranslateState {
        guard self.text == text, requested else { return .translating }
        return service.state
    }

    func cancel() {
        guard text != nil else { return }
        pending?.cancel()
        text = nil
        requested = false
        service.translate("")
    }
}

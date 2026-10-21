// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Combine
import Foundation

/// One request at a time: a newer request replaces the older one, and an older
/// answer that arrives late is dropped. Nothing here touches the network; the
/// backend decides how the Mac translates.
@MainActor
final class TranslateService: ObservableObject {
    @Published private(set) var state: TranslateState = .idle

    private let backend: TranslateBackend
    private let isSupported: () -> Bool
    private var task: Task<Void, Never>?
    private var serial = 0

    init(backend: TranslateBackend,
         isSupported: @escaping () -> Bool = { TranslateAvailability.isSupported() }) {
        self.backend = backend
        self.isSupported = isSupported
    }

    /// `direction` nil lets the text decide; the swap control passes one.
    func translate(_ text: String, direction: TranslateDirection? = nil) {
        serial += 1
        let current = serial
        task?.cancel()
        task = nil
        guard isSupported() else {
            state = .unavailable
            return
        }
        guard let resolved = direction ?? TranslateDirection.detect(text) else {
            state = .idle
            return
        }
        state = .translating
        task = Task { [backend] in
            let outcome: TranslateState
            do {
                outcome = .result(try await backend.translate(text, direction: resolved))
            } catch TranslateBackendError.languagePackMissing(let code) {
                outcome = .needsLanguagePack(code)
            } catch is CancellationError {
                return
            } catch {
                outcome = .failed
            }
            guard current == self.serial else { return }
            self.state = outcome
        }
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI
import Translation

/// Apple hands out a translation session only to a SwiftUI view that is on
/// screen. The backend keeps the one pending request; whichever view carries
/// `translateHost()` picks it up, translates on the Mac and answers.
@available(macOS 15.0, *)
@MainActor
final class HostedTranslateBackend: TranslateBackend, ObservableObject {
    static let shared = HostedTranslateBackend()

    struct Request: Equatable {
        let id: Int
        let text: String
        let direction: TranslateDirection
    }

    @Published private(set) var request: Request?
    private var continuation: CheckedContinuation<String, Error>?
    private var nextID = 0
    private var hosts = 0

    func hostAppeared() { hosts += 1 }

    func hostDisappeared() {
        hosts = max(0, hosts - 1)
        if hosts == 0 { finish(.failure(CancellationError())) }
    }

    func translate(_ text: String, direction: TranslateDirection) async throws -> String {
        guard hosts > 0 else { throw TranslateBackendError.noHost }
        finish(.failure(CancellationError()))
        nextID += 1
        let id = nextID
        request = Request(id: id, text: text, direction: direction)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation = $0 }
        } onCancel: {
            Task { @MainActor in self.cancel(id) }
        }
    }

    func complete(id: Int, result: Result<String, Error>) {
        guard request?.id == id else { return }
        finish(result)
    }

    private func cancel(_ id: Int) {
        guard request?.id == id else { return }
        finish(.failure(CancellationError()))
    }

    private func finish(_ result: Result<String, Error>) {
        request = nil
        let pending = continuation
        continuation = nil
        pending?.resume(with: result)
    }
}

@available(macOS 15.0, *)
private struct TranslateHostModifier: ViewModifier {
    @ObservedObject var backend: HostedTranslateBackend
    @State private var configuration: TranslationSession.Configuration?

    func body(content: Content) -> some View {
        content
            .onAppear { backend.hostAppeared() }
            .onDisappear { backend.hostDisappeared() }
            .onChange(of: backend.request) { _, request in
                guard let request else { return }
                let source = request.direction.source
                let target = request.direction.target
                if configuration?.source == source && configuration?.target == target {
                    configuration?.invalidate()
                } else {
                    configuration = TranslationSession.Configuration(source: source, target: target)
                }
            }
            .translationTask(configuration) { session in
                guard let request = backend.request else { return }
                do {
                    let response = try await session.translate(request.text)
                    backend.complete(id: request.id, result: .success(response.targetText))
                } catch {
                    let failure: Error = Self.isMissingPack(error)
                        ? TranslateBackendError.languagePackMissing(request.direction.target.minimalIdentifier)
                        : error
                    backend.complete(id: request.id, result: .failure(failure))
                }
            }
    }

    /// Only macOS 26 names this case. Before it, the system's own download
    /// prompt handles a missing pack and a refusal arrives as a plain failure.
    private static func isMissingPack(_ error: Error) -> Bool {
        if #available(macOS 26.0, *) {
            return TranslationError.notInstalled ~= error
        }
        return false
    }
}

extension View {
    /// Lets translation run while this view is on screen. A no-op before
    /// macOS 15, where translate is not offered.
    @ViewBuilder
    func translateHost() -> some View {
        if #available(macOS 15.0, *) {
            modifier(TranslateHostModifier(backend: .shared))
        } else {
            self
        }
    }
}

@MainActor
private final class UnsupportedTranslateBackend: TranslateBackend {
    func translate(_ text: String, direction: TranslateDirection) async throws -> String {
        throw TranslateBackendError.noHost
    }
}

extension TranslateService {
    static let shared: TranslateService = {
        if #available(macOS 15.0, *) {
            return TranslateService(backend: HostedTranslateBackend.shared)
        }
        return TranslateService(backend: UnsupportedTranslateBackend())
    }()
}

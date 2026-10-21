// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Relative track changes keep press order across recording changes. Resetting
/// the selected player's lifetime invalidates every unsent command.
final class NotchTransportCommands: @unchecked Sendable {
    static let maximumPending = 32
    private let lock = NSLock()
    private let schedule: (@escaping () -> Void) -> Void
    private var lifetime = DispatchWorkItem {}
    private var count = 0

    init(schedule: @escaping (@escaping () -> Void) -> Void) { self.schedule = schedule }

    func reset() {
        lock.lock()
        lifetime.cancel()
        lifetime = DispatchWorkItem {}
        count = 0
        lock.unlock()
    }

    func submit(_ send: @escaping (DispatchWorkItem) -> Void) -> Bool {
        lock.lock()
        guard count < Self.maximumPending else { lock.unlock(); return false }
        let requested = lifetime
        count += 1
        lock.unlock()
        schedule { [weak self] in
            guard let self else { return }
            defer {
                self.lock.lock()
                if self.lifetime === requested { self.count -= 1 }
                self.lock.unlock()
            }
            guard !requested.isCancelled else { return }
            send(requested)
        }
        return true
    }
}

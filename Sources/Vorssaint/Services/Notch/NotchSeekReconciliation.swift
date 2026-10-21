// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// The released seek starts a clock immediately. Old readings cannot replace
/// it while the player settles; a matching reading hands ownership back.
struct NotchSeekReconciliation {
    private struct Pending {
        var clock: NotchPlayback
        var observed: NotchPlayback
        let issuedAt: Date
        let deadline: Date
    }
    private var pending: Pending?
    private var latest: NotchPlayback?

    mutating func begin(_ playback: NotchPlayback, position: Double, now: Date = Date()) -> NotchPlayback {
        let clock = playback.atPosition(position, sampledAt: now)
        pending = Pending(clock: clock, observed: playback, issuedAt: now, deadline: now.addingTimeInterval(4))
        return clock
    }

    mutating func receive(_ playback: NotchPlayback?, now: Date = Date()) -> NotchPlayback? {
        guard let playback else { self = Self(); return nil }
        if var pending, Self.sameRecording(playback, pending.clock) {
            if playback.sampledAt < pending.issuedAt, now < pending.deadline { return pending.clock }
            pending.observed = playback
            let expected = pending.clock.position(at: playback.sampledAt)
            if abs(playback.elapsed - expected) <= 1.5 || now >= pending.deadline {
                self.pending = nil
                latest = playback
                return playback
            }
            // Preserve a fresh pause/rate update without restoring its old position.
            pending.clock = playback.atPosition(pending.clock.position(at: now), sampledAt: now)
            self.pending = pending
            return pending.clock
        }
        pending = nil
        if let latest, Self.sameRecording(playback, latest), playback.sampledAt < latest.sampledAt { return latest }
        latest = playback
        return playback
    }

    mutating func reject() -> NotchPlayback? {
        let observed = pending?.observed
        pending = nil
        if let observed { latest = observed }
        return observed
    }

    private static func sameRecording(_ first: NotchPlayback, _ second: NotchPlayback) -> Bool {
        first.commandContext == second.commandContext
            && first.track.appPID == second.track.appPID
            && first.automationItemIdentifier == second.automationItemIdentifier
    }
}

extension NotchPlayback {
    func atPosition(_ position: Double, sampledAt: Date) -> NotchPlayback {
        NotchPlayback(track: track, isPlaying: isPlaying, elapsed: min(duration, max(0, position)),
            duration: duration, rate: rate, sampledAt: sampledAt, canSeek: canSeek, hasPosition: hasPosition,
            itemIdentifier: itemIdentifier, commandContext: commandContext,
            canSendCommandsDirectly: canSendCommandsDirectly, automationItemIdentifier: automationItemIdentifier,
            canSkipNext: canSkipNext, canSkipPrevious: canSkipPrevious)
    }
}

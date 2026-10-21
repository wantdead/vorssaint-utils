// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum NotchSeekReconciliationTests {
    static func run(_ suite: TestSuite) {
        let now = Date(timeIntervalSince1970: 1_000)
        let context = NotchPlaybackContext(pid: 42, revision: UUID())
        func reading(_ elapsed: Double, _ offset: Double, playing: Bool = true,
                     revision: NotchPlaybackContext? = nil) -> NotchPlayback {
            NotchPlayback(track: .init(title: "Song", artist: "Artist", album: "Album", artworkData: nil,
                appBundleIdentifier: "test.player", appPID: 42), isPlaying: playing, elapsed: elapsed,
                duration: 200, rate: playing ? 1 : 0, sampledAt: now.addingTimeInterval(offset),
                canSeek: true, commandContext: revision ?? context)
        }
        var state = NotchSeekReconciliation()
        let released = state.begin(reading(100, -1), position: 20, now: now)
        suite.expect(released.position(at: now.addingTimeInterval(1)) == 21,
            "a released rewind advances immediately instead of freezing until a metadata acknowledgment")
        let stale = state.receive(reading(101, -0.1), now: now.addingTimeInterval(1))
        suite.expect(stale?.position(at: now.addingTimeInterval(1)) == 21,
            "a read captured before rewinding cannot restore the old clock after release")
        let settling = state.receive(reading(102, 1), now: now.addingTimeInterval(1))
        suite.expect(settling?.elapsed == 21,
            "a newly timestamped old position also waits for the seek acknowledgment")
        let acknowledged = reading(21.2, 1.2)
        suite.expect(state.receive(acknowledged, now: now.addingTimeInterval(1.2)) == acknowledged,
            "the matching source clock takes over without changing the visible position")
        suite.expect(state.receive(reading(101, 0.5), now: now.addingTimeInterval(1.3)) == acknowledged,
            "an out-of-order old reading cannot undo a confirmed rewind")
        _ = state.begin(acknowledged, position: 5, now: now.addingTimeInterval(1.5))
        suite.expect(state.receive(acknowledged, now: now.addingTimeInterval(1.6))?.elapsed == 5,
            "a second seek supersedes the first acknowledgment")

        state = NotchSeekReconciliation()
        _ = state.begin(reading(100, -1, playing: false), position: 20, now: now)
        let paused = state.receive(reading(100, 1, playing: false), now: now.addingTimeInterval(1))
        suite.expect(paused?.position(at: now.addingTimeInterval(3)) == 20,
            "paused seeking holds the new position without inventing playback progress")
        suite.expect(state.reject()?.elapsed == 100,
            "a failed command restores the actual observed source position")

        _ = state.begin(reading(100, -1), position: 20, now: now)
        let nextTrack = reading(0, 0.2, revision: .init(pid: 42, revision: UUID()))
        suite.expect(state.receive(nextTrack, now: now.addingTimeInterval(0.2)) == nextTrack,
            "a new recording immediately ends the old recording's seek handoff")
        _ = state.begin(reading(100, -1), position: 20, now: now)
        let ignored = reading(100, -0.5)
        suite.expect(state.receive(ignored, now: now.addingTimeInterval(5)) == ignored,
            "an ignored seek eventually returns to source truth rather than retaining a false clock")
        _ = state.begin(reading(100, -1), position: 20, now: now)
        suite.expect(state.receive(nil, now: now.addingTimeInterval(1)) == nil,
            "disconnecting clears the optimistic seek clock")
    }
}

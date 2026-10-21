// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import CoreGraphics
import Foundation

/// A title too long for its row scrolls past once, then rests, as a player's
/// does. The text runs twice with a gap between, so the second copy arrives
/// exactly where the first began and the loop has no seam.
enum NotchMarquee {
    static let gap: CGFloat = 36
    static let speed: CGFloat = 28
    static let rest: TimeInterval = 2.5

    /// How far one copy travels per loop; nil when the text fits and stays put.
    static func travel(text: CGFloat, container: CGFloat) -> CGFloat? {
        guard text.isFinite, container.isFinite, container > 0, text > container + 0.5 else { return nil }
        return text + gap
    }

    static func cycle(travel: CGFloat) -> TimeInterval {
        rest + TimeInterval(travel / speed)
    }

    /// The horizontal offset, zero while resting and then moving left at a
    /// steady speed until the second copy sits where the first began.
    static func offset(travel: CGFloat, elapsed: TimeInterval) -> CGFloat {
        guard travel > 0, elapsed.isFinite, elapsed >= 0 else { return 0 }
        let phase = elapsed.truncatingRemainder(dividingBy: cycle(travel: travel))
        return phase < rest ? 0 : -CGFloat(phase - rest) * speed
    }
}

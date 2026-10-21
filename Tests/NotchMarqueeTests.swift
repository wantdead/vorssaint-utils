// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import CoreGraphics
import Foundation

enum NotchMarqueeTests {
    static func run(_ suite: TestSuite) {
        suite.expect(NotchMarquee.travel(text: 180, container: 200) == nil
            && NotchMarquee.travel(text: 200.4, container: 200) == nil
            && NotchMarquee.travel(text: 300, container: 0) == nil
            && NotchMarquee.travel(text: .nan, container: 200) == nil,
            "a title that fits, or a row not yet measured, never scrolls")
        let travel = NotchMarquee.travel(text: 300, container: 200)
        suite.expect(travel == 300 + NotchMarquee.gap, "a long title travels its own width and the gap")
        guard let travel else { return }
        suite.expect(NotchMarquee.offset(travel: travel, elapsed: 0) == 0
            && NotchMarquee.offset(travel: travel, elapsed: NotchMarquee.rest - 0.01) == 0,
            "the title rests at its start before it moves")
        let moving = NotchMarquee.offset(travel: travel, elapsed: NotchMarquee.rest + 2)
        suite.expect(abs(moving + 2 * NotchMarquee.speed) < 0.001, "the title then moves left at a steady speed")
        let cycle = NotchMarquee.cycle(travel: travel)
        suite.expect(abs(NotchMarquee.offset(travel: travel, elapsed: cycle - 0.001) + travel) < 0.1
            && NotchMarquee.offset(travel: travel, elapsed: cycle) == 0
            && NotchMarquee.offset(travel: travel, elapsed: cycle * 3 + 1) == 0,
            "the second copy lands where the first began, and every loop repeats")
        suite.expect(NotchMarquee.offset(travel: travel, elapsed: -1) == 0
            && NotchMarquee.offset(travel: travel, elapsed: .infinity) == 0
            && NotchMarquee.offset(travel: 0, elapsed: 5) == 0,
            "a bad clock or an empty travel holds the title still")
    }
}

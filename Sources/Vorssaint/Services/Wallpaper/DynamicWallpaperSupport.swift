// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum DynamicWallpaperSupport {
    enum Mode: String, CaseIterable, Identifiable {
        case off, appearance, schedule
        var id: String { rawValue }
    }

    enum Period: String, CaseIterable, Identifiable {
        case day, night
        var id: String { rawValue }
        var symbol: String { self == .day ? "sun.max" : "moon" }
    }

    struct Schedule: Equatable {
        let dayStart: Int
        let nightStart: Int

        init(dayStart: Int = 7 * 60, nightStart: Int = 19 * 60) {
            self.dayStart = (0..<1440).contains(dayStart) ? dayStart : 7 * 60
            self.nightStart = (0..<1440).contains(nightStart) ? nightStart : 19 * 60
        }

        var isValid: Bool { dayStart != nightStart }

        func start(for period: Period) -> Int {
            period == .day ? dayStart : nightStart
        }

        func period(at date: Date, calendar: Calendar = .current) -> Period? {
            guard isValid else { return nil }
            // Compare actual transitions, including a skipped or repeated DST hour.
            let transitions = Period.allCases.compactMap { period -> (Period, Date)? in
                let minute = start(for: period)
                let components = DateComponents(hour: minute / 60, minute: minute % 60, second: 0)
                guard let previous = calendar.nextDate(
                    after: date.addingTimeInterval(1), matching: components,
                    matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .backward
                ) else { return nil }
                return (period, previous)
            }
            return transitions.max { $0.1 < $1.1 }?.0
        }

        func nextTransition(after date: Date, calendar: Calendar = .current) -> Date? {
            guard isValid else { return nil }
            return Period.allCases.compactMap { period in
                let minute = start(for: period)
                return calendar.nextDate(
                    after: date, matching: DateComponents(hour: minute / 60, minute: minute % 60, second: 0),
                    matchingPolicy: .nextTime, repeatedTimePolicy: .first
                )
            }.min()
        }
    }

    static func period(mode: Mode, schedule: Schedule, date: Date = Date(),
                       isDark: Bool, calendar: Calendar = .current) -> Period? {
        switch mode {
        case .off: return nil
        case .appearance: return isDark ? .night : .day
        case .schedule: return schedule.period(at: date, calendar: calendar)
        }
    }
}

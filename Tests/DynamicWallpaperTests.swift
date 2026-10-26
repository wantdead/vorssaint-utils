// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation
import AppKit

enum DynamicWallpaperContract {
    static func run(_ suite: TestSuite) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        func date(_ hour: Int, _ minute: Int = 0) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 10, day: 26,
                                               hour: hour, minute: minute))!
        }
        let schedule = DynamicWallpaperSupport.Schedule()
        suite.expect(schedule.period(at: date(6, 59), calendar: calendar) == .night
            && schedule.period(at: date(7), calendar: calendar) == .day
            && schedule.period(at: date(18, 59), calendar: calendar) == .day
            && schedule.period(at: date(19), calendar: calendar) == .night,
            "day/night changes exactly at the selected local minute")
        suite.expect(schedule.period(at: date(0), calendar: calendar) == .night,
                     "the night image remains selected across midnight")
        let overnight = DynamicWallpaperSupport.Schedule(dayStart: 20 * 60, nightStart: 6 * 60)
        suite.expect(overnight.period(at: date(23), calendar: calendar) == .day
            && overnight.period(at: date(3), calendar: calendar) == .day
            && overnight.period(at: date(12), calendar: calendar) == .night,
            "a custom day interval can cross midnight")
        suite.expect(schedule.nextTransition(after: date(7), calendar: calendar) == date(19)
            && schedule.nextTransition(after: date(6), calendar: calendar) == date(7),
            "the next timer advances past a boundary already reached")
        let invalid = DynamicWallpaperSupport.Schedule(dayStart: 420, nightStart: 420)
        suite.expect(!invalid.isValid && invalid.period(at: date(12), calendar: calendar) == nil
            && invalid.nextTransition(after: date(12), calendar: calendar) == nil,
            "equal start times pause switching instead of causing a timer loop")
        suite.expect(DynamicWallpaperSupport.Schedule(dayStart: -1, nightStart: 1440) == schedule,
                     "invalid stored times fall back to the built-in schedule")
        suite.expect(DynamicWallpaperSupport.period(mode: .off, schedule: schedule,
            date: date(12), isDark: false) == nil,
            "Off never requests an image")
        suite.expect(DynamicWallpaperSupport.period(mode: .appearance, schedule: invalid,
            date: date(12), isDark: true) == .night
            && DynamicWallpaperSupport.period(mode: .appearance, schedule: invalid,
                date: date(0), isDark: false) == .day,
            "appearance mode follows macOS rather than the clock or custom schedule")

        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let spring = calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 1, minute: 59))!
        let skippedHour = DynamicWallpaperSupport.Schedule(dayStart: 150, nightStart: 1140)
        let next = skippedHour.nextTransition(after: spring, calendar: calendar)!
        suite.expect(calendar.component(.hour, from: next) == 3
            && calendar.component(.minute, from: next) == 0
            && skippedHour.period(at: next, calendar: calendar) == .day,
            "a daylight-saving gap advances the skipped start to the next valid time")
        let fall = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 0))!
        let repeatedHour = DynamicWallpaperSupport.Schedule(dayStart: 90, nightStart: 1140)
        let first = repeatedHour.nextTransition(after: fall, calendar: calendar)!
        suite.expect(repeatedHour.period(at: first.addingTimeInterval(3600), calendar: calendar) == .day
            && calendar.component(.hour, from: repeatedHour.nextTransition(after: first, calendar: calendar)!) == 19,
            "the repeated autumn hour keeps the day image and does not switch twice")

        lifecycle(suite)
        for language in AppLanguage.allCases {
            let text = DynamicWallpaperStrings.localized(language)
            suite.expect([text.title, text.off, text.appearance, text.schedule, text.day, text.night,
                          text.chooseImage, text.missingImages, text.appearanceHint, text.scheduleHint,
                          text.invalidTimes, text.unavailable].allSatisfy { !$0.isEmpty },
                         "dynamic wallpaper controls are translated for \(language.rawValue)")
        }
        let keys = SettingsBackupSupport.exportKeys()
        suite.expect(keys.contains(DefaultsKey.wallpaperDynamicMode)
            && keys.contains(DefaultsKey.wallpaperDayStart) && keys.contains(DefaultsKey.wallpaperNightStart)
            && !keys.contains(DefaultsKey.wallpaperDayBookmark) && !keys.contains(DefaultsKey.wallpaperNightBookmark),
            "backups carry switching preferences without machine-specific image access")
    }

    private static func lifecycle(_ suite: TestSuite) {
        let name = "com.vorssaint.tests.dynamic-wallpaper.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        let folder = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent(UUID().uuidString)
        defer {
            defaults.removePersistentDomain(forName: name)
            try? FileManager.default.removeItem(at: folder)
        }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let day = folder.appendingPathComponent("day.png")
        let night = folder.appendingPathComponent("night.png")
        func paths(_ urls: [URL]) -> [String] {
            urls.map { $0.resolvingSymlinksInPath().path }
        }
        try? Data([0]).write(to: day)
        try? Data([1]).write(to: night)
        defaults.set("Light", forKey: "AppleInterfaceStyle")
        var requested: [URL] = []
        var completions: [(Bool) -> Void] = []
        var cancellations = 0
        let service = DynamicWallpaperService(defaults: defaults, apply: { url, completion in
            requested.append(url)
            completions.append(completion)
        }, cancelApply: { cancellations += 1 })
        defer { service.stop() }
        service.syncWithPreferences(isAvailable: true)
        service.setMode(.appearance)
        service.setImage(day, for: .day)
        suite.expect(requested.isEmpty, "a partial image pair never changes the desktop")
        service.setImage(night, for: .night)
        suite.expect(paths(requested) == paths([day]),
                     "a complete pair applies the current system appearance")
        completions.last?(true)
        defaults.set("Dark", forKey: "AppleInterfaceStyle")
        NotificationCenter.default.post(name: .NSSystemClockDidChange, object: nil)
        suite.expect(paths(requested) == paths([day, night]),
                     "a system change reevaluates the image while the panel is closed")
        let lateCompletion = completions.last
        service.setMode(.off)
        lateCompletion?(true)
        NotificationCenter.default.post(name: .NSSystemClockDidChange, object: nil)
        suite.expect(requested.count == 2 && service.currentPeriod == nil && cancellations > 0,
                     "Off cancels pending work and removes observers without accepting a late completion")
        service.setMode(.appearance)
        suite.expect(paths(requested) == paths([day, night, night]),
                     "turning switching back on restores the bookmarked pair")
        defaults.set("Light", forKey: "AppleInterfaceStyle")
        NotificationCenter.default.post(name: .NSSystemClockDidChange, object: nil)
        completions.last?(true)
        suite.expect(paths(requested) == paths([day, night, night, day]),
                     "an appearance change during a download applies the new image when it finishes")
        completions.last?(true)
        NotificationCenter.default.post(name: .NSSystemClockDidChange, object: nil)
        suite.expect(requested.count == 4, "an unchanged clock check does not rewrite the wallpaper store")
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        completions.last?(true)
        suite.expect(requested.count == 6,
                     "a display change during an apply still refreshes the new desktop")
        completions.last?(true)
        service.stop()
        NotificationCenter.default.post(name: .NSSystemClockDidChange, object: nil)
        suite.expect(requested.count == 6 && service.currentPeriod == nil,
                     "suspending stops observation without erasing the selected mode")
        service.syncWithPreferences(isAvailable: false)
        let count = requested.count
        NotificationCenter.default.post(name: .NSSystemClockDidChange, object: nil)
        service.setImage(day, for: .night)
        suite.expect(requested.count == count && service.currentPeriod == nil,
                     "an unavailable wallpaper feature does no background work")
    }
}

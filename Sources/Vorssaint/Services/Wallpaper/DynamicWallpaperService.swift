// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine

/// Keeps the chosen pair accessible independently of the gallery's lifetime.
final class DynamicWallpaperService: ObservableObject {
    typealias Mode = DynamicWallpaperSupport.Mode
    typealias Period = DynamicWallpaperSupport.Period

    @Published private(set) var mode: Mode = .off
    @Published private(set) var schedule = DynamicWallpaperSupport.Schedule()
    @Published private(set) var images: [Period: URL] = [:]
    @Published private(set) var currentPeriod: Period?
    @Published private(set) var imageUnavailable = false

    private let defaults: UserDefaults
    private let apply: (URL, @escaping (Bool) -> Void) -> Void
    private let cancelApply: () -> Void
    private var scopedURLs: [URL] = []
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var timer: Timer?
    private var generation = UUID()
    private var desktopRevision = UUID()
    private var lastAppliedURL: URL?
    private var isApplying = false
    private var isAvailable = false
    private var isRunning = false

    init(defaults: UserDefaults = .standard,
         apply: @escaping (URL, @escaping (Bool) -> Void) -> Void,
         cancelApply: @escaping () -> Void) {
        self.defaults = defaults
        self.apply = apply
        self.cancelApply = cancelApply
        loadPreferences()
    }

    var hasPair: Bool { Period.allCases.allSatisfy { images[$0] != nil } }

    func syncWithPreferences(isAvailable: Bool) {
        stop()
        self.isAvailable = isAvailable
        loadPreferences()
        guard isAvailable, mode != .off else { return }
        isRunning = true
        resolveImages()
        observe(DistributedNotificationCenter.default(),
                NSNotification.Name("AppleInterfaceThemeChangedNotification"))
        observe(NSWorkspace.shared.notificationCenter, NSWorkspace.didWakeNotification, reapply: true)
        observe(NSWorkspace.shared.notificationCenter, NSWorkspace.activeSpaceDidChangeNotification, reapply: true)
        observe(.default, NSApplication.didChangeScreenParametersNotification, reapply: true)
        observe(.default, NSNotification.Name.NSSystemClockDidChange)
        observe(.default, NSNotification.Name.NSSystemTimeZoneDidChange)
        evaluate()
    }

    func setMode(_ mode: Mode) {
        guard isAvailable, mode != self.mode else { return }
        defaults.set(mode.rawValue, forKey: DefaultsKey.wallpaperDynamicMode)
        syncWithPreferences(isAvailable: isAvailable)
    }

    func setStart(_ minute: Int, for period: Period) {
        guard isAvailable else { return }
        let key = period == .day ? DefaultsKey.wallpaperDayStart : DefaultsKey.wallpaperNightStart
        defaults.set(min(max(minute, 0), 1439), forKey: key)
        syncWithPreferences(isAvailable: isAvailable)
    }

    func setImage(_ url: URL, for period: Period) {
        guard isAvailable, WallpaperSupport.isStillImageURL(url) else { return }
        do {
            let data = try url.bookmarkData(options: .withSecurityScope,
                                            includingResourceValuesForKeys: nil, relativeTo: nil)
            defaults.set(data, forKey: bookmarkKey(for: period))
            syncWithPreferences(isAvailable: isAvailable)
        } catch {
            imageUnavailable = true
        }
    }

    func stop() {
        isRunning = false
        generation = UUID()
        timer?.invalidate()
        timer = nil
        observers.forEach { $0.0.removeObserver($0.1) }
        observers.removeAll()
        cancelApply()
        isApplying = false
        lastAppliedURL = nil
        currentPeriod = nil
        scopedURLs.forEach { $0.stopAccessingSecurityScopedResource() }
        scopedURLs.removeAll()
    }

    private func loadPreferences() {
        mode = Mode(rawValue: defaults.string(forKey: DefaultsKey.wallpaperDynamicMode) ?? "") ?? .off
        schedule = DynamicWallpaperSupport.Schedule(
            dayStart: defaults.object(forKey: DefaultsKey.wallpaperDayStart) as? Int ?? 7 * 60,
            nightStart: defaults.object(forKey: DefaultsKey.wallpaperNightStart) as? Int ?? 19 * 60
        )
    }

    private func bookmarkKey(for period: Period) -> String {
        period == .day ? DefaultsKey.wallpaperDayBookmark : DefaultsKey.wallpaperNightBookmark
    }

    private func resolveImages() {
        images = [:]
        imageUnavailable = false
        for period in Period.allCases {
            let key = bookmarkKey(for: period)
            guard let data = defaults.data(forKey: key) else { continue }
            do {
                var stale = false
                let url = try URL(resolvingBookmarkData: data,
                                  options: [.withSecurityScope, .withoutUI, .withoutMounting],
                                  relativeTo: nil, bookmarkDataIsStale: &stale)
                if url.startAccessingSecurityScopedResource() { scopedURLs.append(url) }
                if stale, let renewed = try? url.bookmarkData(options: .withSecurityScope,
                    includingResourceValuesForKeys: nil, relativeTo: nil) {
                    defaults.set(renewed, forKey: key)
                }
                images[period] = url
            } catch {
                imageUnavailable = true
            }
        }
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, reapply: Bool = false) {
        let generation = generation
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            guard let self, self.generation == generation else { return }
            if reapply {
                self.desktopRevision = UUID()
                self.lastAppliedURL = nil
            }
            self.evaluate()
        }
        observers.append((center, token))
    }

    private func evaluate() {
        timer?.invalidate()
        timer = nil
        guard isRunning, isAvailable, mode != .off else { return }
        currentPeriod = DynamicWallpaperSupport.period(
            mode: mode, schedule: schedule,
            isDark: defaults.string(forKey: "AppleInterfaceStyle") == "Dark"
        )
        if mode == .schedule, let next = schedule.nextTransition(after: Date()) {
            scheduleEvaluation(at: next)
        }
        guard !isApplying, hasPair, let period = currentPeriod, let url = images[period],
              lastAppliedURL != url else { return }
        let token = generation
        let revision = desktopRevision
        isApplying = true
        apply(url) { [weak self] success in
            guard let self, self.generation == token else { return }
            self.isApplying = false
            if success {
                self.lastAppliedURL = revision == self.desktopRevision ? url : nil
                // The appearance or clock may have changed during an iCloud download.
                self.evaluate()
            } else {
                self.scheduleEvaluation(at: Date().addingTimeInterval(60))
            }
        }
    }

    private func scheduleEvaluation(at date: Date) {
        timer?.invalidate()
        let timer = Timer(fire: date, interval: 0, repeats: false) { [weak self] _ in
            self?.evaluate()
        }
        timer.tolerance = 1
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
}

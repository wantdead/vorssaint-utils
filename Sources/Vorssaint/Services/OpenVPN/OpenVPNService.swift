// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Combine
import Darwin
import Foundation

/// Shows and drives OpenVPN Connect. The app owns the tunnel and asks for the
/// PIN in its own window; this only sends it commands and reads its log.
/// Status polling runs while a panel or quick-access circle is visible.
final class OpenVPNService: ObservableObject {
    static let shared = OpenVPNService(
        runCommand: { arguments in
            BoundedProcessRunner.run(OpenVPNSupport.appExecutablePath, arguments,
                                     timeout: commandTimeout, maxOutputBytes: 65_536)
        },
        readLogTail: readLiveLogTail,
        interfaceHasAddress: liveInterfaceHasAddress,
        appInstalled: { FileManager.default.isExecutableFile(atPath: OpenVPNSupport.appExecutablePath) },
        now: Date.init)

    @Published private(set) var status: OpenVPNStatus = .disconnected
    @Published private(set) var profiles: [OpenVPNProfile] = []

    private static let commandTimeout: TimeInterval = 10
    private static let pollInterval: TimeInterval = 2
    private static let profileReloadInterval: TimeInterval = 30
    /// The log stays silent while OpenVPN Connect waits for the PIN, so a
    /// connect Vorssaint started reads as connecting until the log moves.
    private static let pendingConnectTimeout: TimeInterval = 120

    private struct PendingConnect {
        let baselineMarker: String?
        let since: Date
    }

    private let runCommand: ([String]) -> BoundedProcessRunner.Result
    private let readLogTail: () -> String?
    private let interfaceHasAddress: (String) -> Bool
    private let appInstalled: () -> Bool
    private let now: () -> Date
    private let background: (@escaping () -> Void) -> Void
    private let main: (@escaping () -> Void) -> Void

    private var pending: PendingConnect?
    private var commandFailed = false
    private var viewers = 0
    private var timer: Timer?
    private var profilesLoadedAt: Date?

    init(runCommand: @escaping ([String]) -> BoundedProcessRunner.Result,
         readLogTail: @escaping () -> String?,
         interfaceHasAddress: @escaping (String) -> Bool,
         appInstalled: @escaping () -> Bool,
         now: @escaping () -> Date,
         background: @escaping (@escaping () -> Void) -> Void = {
             DispatchQueue.global(qos: .userInitiated).async(execute: $0)
         },
         main: @escaping (@escaping () -> Void) -> Void = { DispatchQueue.main.async(execute: $0) }) {
        self.runCommand = runCommand
        self.readLogTail = readLogTail
        self.interfaceHasAddress = interfaceHasAddress
        self.appInstalled = appInstalled
        self.now = now
        self.background = background
        self.main = main
    }

    /// Call when a status view appears. Polling runs while any viewer is visible.
    func panelDidAppear() {
        viewers += 1
        reloadProfilesIfStale()
        refresh()
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            self?.pollIfActive()
        }
    }

    func panelDidDisappear() {
        viewers = max(0, viewers - 1)
        guard viewers == 0 else { return }
        timer?.invalidate()
        timer = nil
    }

    func pollIfActive() {
        guard viewers > 0 else { return }
        refresh()
    }

    func refresh() {
        guard appInstalled() else {
            status = .unavailable(.appMissing)
            return
        }
        if commandFailed {
            status = .unavailable(.commandFailed)
            return
        }
        guard let tail = readLogTail() else {
            status = .unavailable(.logUnreadable)
            return
        }
        if let pending {
            let moved = OpenVPNSupport.lastEventMarker(tail) != pending.baselineMarker
            let expired = now().timeIntervalSince(pending.since) > Self.pendingConnectTimeout
            if moved || expired {
                self.pending = nil
            } else {
                status = .connecting
                return
            }
        }
        status = OpenVPNSupport.resolveStatus(OpenVPNSupport.parseLogState(tail),
                                              profiles: profiles,
                                              interfaceHasAddress: interfaceHasAddress)
    }

    func connect(profileID: String) {
        guard let arguments = OpenVPNSupport.connectArguments(profileID: profileID) else { return }
        guard appInstalled() else {
            status = .unavailable(.appMissing)
            return
        }
        commandFailed = false
        pending = PendingConnect(baselineMarker: readLogTail().flatMap(OpenVPNSupport.lastEventMarker),
                                 since: now())
        status = .connecting
        run(arguments)
    }

    func disconnect() {
        guard appInstalled() else {
            status = .unavailable(.appMissing)
            return
        }
        commandFailed = false
        pending = nil
        run(OpenVPNSupport.disconnectArguments)
        refresh()
    }

    /// Brings OpenVPN Connect forward, where the PIN is entered.
    func raiseApp() {
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: OpenVPNSupport.appBundlePath),
                                           configuration: NSWorkspace.OpenConfiguration())
    }

    private func run(_ arguments: [String]) {
        background { [self] in
            let result = runCommand(arguments)
            main { [self] in
                guard result.timedOut || result.status != 0 else { return }
                commandFailed = true
                pending = nil
                status = .unavailable(.commandFailed)
            }
        }
    }

    private func reloadProfilesIfStale() {
        if let loaded = profilesLoadedAt, !profiles.isEmpty,
           now().timeIntervalSince(loaded) < Self.profileReloadInterval { return }
        guard appInstalled() else { return }
        profilesLoadedAt = now()
        background { [self] in
            let result = runCommand(["--list-profiles"])
            let parsed = result.timedOut ? [] : OpenVPNSupport.parseProfiles(result.output)
            main { [self] in
                if parsed != profiles { profiles = parsed }
                refresh()
            }
        }
    }

    private static func readLiveLogTail() -> String? {
        let url = OpenVPNSupport.logURL(home: FileManager.default.homeDirectoryForCurrentUser)
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd() else { return nil }
        let limit = UInt64(OpenVPNSupport.logTailBytes)
        guard (try? handle.seek(toOffset: size > limit ? size - limit : 0)) != nil,
              let data = try? handle.readToEnd() else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    private static func liveInterfaceHasAddress(_ name: String) -> Bool {
        var first: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&first) == 0 else { return false }
        defer { freeifaddrs(first) }
        var current = first
        while let entry = current?.pointee {
            defer { current = entry.ifa_next }
            guard let address = entry.ifa_addr,
                  Int32(address.pointee.sa_family) == AF_INET,
                  String(cString: entry.ifa_name) == name else { continue }
            return true
        }
        return false
    }
}

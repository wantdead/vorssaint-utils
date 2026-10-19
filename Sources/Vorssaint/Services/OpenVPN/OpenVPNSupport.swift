// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// A profile saved in OpenVPN Connect, as listed by its `--list-profiles` flag.
struct OpenVPNProfile: Equatable, Identifiable {
    let id: String
    let name: String
    let host: String
}

/// What OpenVPN Connect's log says about the most recent session.
enum OpenVPNLogState: Equatable {
    case noEvents
    case inProgress
    case connected(interface: String?, host: String?)
    case ended
}

enum OpenVPNUnavailableReason: Equatable {
    case appMissing
    case logUnreadable
    case commandFailed
}

enum OpenVPNStatus: Equatable {
    case unavailable(OpenVPNUnavailableReason)
    case disconnected
    case connecting
    case connected(profileName: String?)
}

/// Parsing and status rules for controlling OpenVPN Connect. Its control flags
/// and its log are not a documented interface, so everything that depends on
/// their wording lives here, behind tests.
enum OpenVPNSupport {
    static let appExecutablePath =
        "/Applications/OpenVPN Connect/OpenVPN Connect.app/Contents/MacOS/OpenVPN Connect"
    static let logTailBytes = 65_536
    static let disconnectArguments = ["--disconnect-shortcut"]

    private static let inProgressEvents: Set<String> = [
        "RESOLVE", "WAIT", "CONNECTING", "GET_CONFIG", "ASSIGN_IP", "RECONNECTING", "PAUSE", "RESUME",
    ]
    private static let endedEvents: Set<String> = ["DISCONNECTED", "EPKI_ERROR", "TUN_ERROR"]

    // Entries are separated by U+23CE, not reliably by newlines, so the log is
    // scanned for event entries instead of being split into lines.
    private static let eventPattern = try? NSRegularExpression(
        pattern: #"\[([A-Z][a-z]{2} \d{1,2}, \d{4}, \d{2}:\d{2}:\d{2})\] EVENT: ([A-Z_]+)"#)
    private static let interfacePattern = try? NSRegularExpression(pattern: #"Connected via ([^\s\x{23CE}]+)"#)

    static func logURL(home: URL) -> URL {
        home.appendingPathComponent("Library/Application Support/OpenVPN Connect/log/ovpn.log")
    }

    private struct ProfileRecord: Decodable {
        let id: String
        let name: String
        let host: String?
    }

    /// The app prints a JSON array, possibly with other text around it.
    static func parseProfiles(_ output: Data) -> [OpenVPNProfile] {
        guard let text = String(data: output, encoding: .utf8),
              let open = text.firstIndex(of: "["),
              let close = text.lastIndex(of: "]"), open < close,
              let json = String(text[open...close]).data(using: .utf8),
              let records = try? JSONDecoder().decode([ProfileRecord].self, from: json)
        else { return [] }
        return records.map { OpenVPNProfile(id: $0.id, name: $0.name, host: $0.host ?? "") }
    }

    private struct LogEvent {
        let stamp: String
        let name: String
        let range: NSRange
    }

    private static func events(in tail: String) -> [LogEvent] {
        guard let eventPattern else { return [] }
        let text = tail as NSString
        return eventPattern.matches(in: tail, range: NSRange(location: 0, length: text.length)).map {
            LogEvent(stamp: text.substring(with: $0.range(at: 1)),
                     name: text.substring(with: $0.range(at: 2)),
                     range: $0.range)
        }
    }

    /// The state the last recognised event leaves. Unknown event names are skipped.
    static func parseLogState(_ tail: String) -> OpenVPNLogState {
        let all = events(in: tail)
        guard let index = all.lastIndex(where: {
            $0.name == "CONNECTED" || inProgressEvents.contains($0.name) || endedEvents.contains($0.name)
        }) else { return .noEvents }
        let event = all[index]
        if endedEvents.contains(event.name) { return .ended }
        if inProgressEvents.contains(event.name) { return .inProgress }

        let text = tail as NSString
        let afterEvent = NSRange(location: NSMaxRange(event.range),
                                 length: text.length - NSMaxRange(event.range))
        var detail = text.substring(with: afterEvent)
        if let separator = detail.firstIndex(of: "\u{23CE}") { detail = String(detail[..<separator]) }
        var host = detail.split(separator: " ").first.map(String.init)
        if let name = host, let colon = name.lastIndex(of: ":") { host = String(name[..<colon]) }
        if host?.isEmpty == true { host = nil }

        // The interface is named by a "Connected via" entry earlier in the same session.
        let sessionStart = index > 0 ? NSMaxRange(all[index - 1].range) : 0
        let session = NSRange(location: sessionStart, length: event.range.location - sessionStart)
        var interface: String?
        if let interfacePattern,
           let match = interfacePattern.matches(in: tail, range: session).last {
            interface = text.substring(with: match.range(at: 1))
        }
        return .connected(interface: interface, host: host)
    }

    /// The timestamp and name of the last event entry, to tell whether the log
    /// has moved since a connect was started.
    static func lastEventMarker(_ tail: String) -> String? {
        events(in: tail).last.map { "\($0.stamp) \($0.name)" }
    }

    /// "Connected" needs the tunnel interface the log names to exist with an
    /// address: other VPN clients own addressed `utun` interfaces too. The
    /// profile name is only given when exactly one profile uses the server host.
    static func resolveStatus(_ log: OpenVPNLogState,
                              profiles: [OpenVPNProfile],
                              interfaceHasAddress: (String) -> Bool) -> OpenVPNStatus {
        switch log {
        case .noEvents, .ended:
            return .disconnected
        case .inProgress:
            return .connecting
        case let .connected(interface, host):
            guard let interface, interfaceHasAddress(interface) else { return .disconnected }
            let matches = host.map { host in profiles.filter { $0.host == host } } ?? []
            return .connected(profileName: matches.count == 1 ? matches[0].name : nil)
        }
    }

    /// Only a numeric id is passed to the app.
    static func connectArguments(profileID: String) -> [String]? {
        guard !profileID.isEmpty, profileID.utf8.allSatisfy({ (48...57).contains($0) }) else { return nil }
        return ["--connect-shortcut=\(profileID)"]
    }
}

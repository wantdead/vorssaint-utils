// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum OpenVPNTests {
    /// OpenVPN Connect separates log entries with U+23CE, and one line can hold two.
    fileprivate static func entry(_ time: String, _ text: String) -> String {
        "\u{23CE}[Oct 19, 2026, \(time)] \(text)"
    }

    fileprivate static let connectedSession =
        entry("21:09:36", "EVENT: DISCONNECTED ")
        + entry("21:09:45", "OpenVPN core 3.11.3 mac arm64 64-bit built on Oct 24 2025 02:51:48")
        + entry("21:09:45", "EVENT: RESOLVE ")
        + entry("21:09:45", "Contacting 192.0.2.10:1194 via TCP")
        + entry("21:09:45", "EVENT: WAIT ")
        + entry("21:09:46", "EVENT: CONNECTING ")
        + entry("21:09:46", "EVENT: GET_CONFIG ")
        + entry("21:09:47", "EVENT: ASSIGN_IP ")
        + entry("21:09:47", "Connected via utun7")
        + entry("21:09:47", "EVENT: CONNECTED vpn.example.com:1194 (192.0.2.10) via /TCP on utun7/198.51.100.4/ gw=[198.51.100.1/] mtu=1400")
        + entry("21:09:47", "MacLifeCycle NET_STATE 1 status=ReachableViaWiFi flags=-R -------")

    fileprivate static let profilesJSON = """
    [
      { "host": "vpn.example.com", "id": "1747746310902", "name": "Office",
        "server-override": "none", "type": "autologin", "username": "" },
      { "host": "192.0.2.10", "id": "1780305640672", "name": "Lab",
        "server-override": "none", "type": "autologin", "username": "" },
      { "host": "192.0.2.10", "id": "1749472453217", "name": "Lab old",
        "server-override": "none", "type": "autologin", "username": "" }
    ]
    """

    static func run(_ suite: TestSuite) {
        // MARK: Profile list

        let profiles = OpenVPNSupport.parseProfiles(Data(profilesJSON.utf8))
        suite.expect(profiles.map(\.id) == ["1747746310902", "1780305640672", "1749472453217"],
                     "profiles keep the app's order and ids")
        suite.expect(profiles.map(\.name) == ["Office", "Lab", "Lab old"], "profiles carry names")
        suite.expect(profiles.map(\.host) == ["vpn.example.com", "192.0.2.10", "192.0.2.10"],
                     "profiles carry hosts")
        suite.expect(OpenVPNSupport.parseProfiles(Data()).isEmpty, "empty output gives no profiles")
        suite.expect(OpenVPNSupport.parseProfiles(Data("garbage".utf8)).isEmpty,
                     "junk output gives no profiles")
        let wrapped = "starting up\n\(profilesJSON)\ndone\n"
        suite.expect(OpenVPNSupport.parseProfiles(Data(wrapped.utf8)).count == 3,
                     "JSON surrounded by other text still parses")

        // MARK: Log state

        suite.expect(OpenVPNSupport.parseLogState(connectedSession)
                        == .connected(interface: "utun7", host: "vpn.example.com"),
                     "a tail ending in CONNECTED names its interface and host")
        suite.expect(OpenVPNSupport.parseLogState(entry("21:09:46", "EVENT: GET_CONFIG ")) == .inProgress,
                     "GET_CONFIG is in progress")
        for name in ["RESOLVE", "WAIT", "CONNECTING", "ASSIGN_IP", "RECONNECTING", "PAUSE", "RESUME"] {
            suite.expect(OpenVPNSupport.parseLogState(entry("21:00:00", "EVENT: \(name) ")) == .inProgress,
                         "\(name) is in progress")
        }
        for name in ["DISCONNECTED", "EPKI_ERROR", "TUN_ERROR"] {
            suite.expect(OpenVPNSupport.parseLogState(entry("21:00:00", "EVENT: \(name) ")) == .ended,
                         "\(name) ends the session")
        }
        suite.expect(OpenVPNSupport.parseLogState("") == .noEvents, "an empty tail has no events")
        suite.expect(OpenVPNSupport.parseLogState(entry("21:00:00", "route add -net")) == .noEvents,
                     "a tail without EVENT entries has no events")
        suite.expect(OpenVPNSupport.parseLogState(connectedSession + entry("21:30:00", "EVENT: SOMETHING_NEW "))
                        == .connected(interface: "utun7", host: "vpn.example.com"),
                     "unknown event names are skipped")
        suite.expect(OpenVPNSupport.parseLogState(connectedSession + entry("21:30:00", "EVENT: PAUSE "))
                        == .inProgress,
                     "the last event wins over an older CONNECTED")
        suite.expect(OpenVPNSupport.parseLogState(connectedSession.replacingOccurrences(of: "Connected via utun7", with: "x"))
                        == .connected(interface: nil, host: "vpn.example.com"),
                     "a CONNECTED entry without a named interface has none")

        let throughDisconnect = entry("21:09:36", "EVENT: DISCONNECTED ")
            + entry("21:09:45", "OpenVPN core 3.11.3 mac arm64 64-bit built on Oct 24 2025 02:51:48")
        suite.expect(OpenVPNSupport.lastEventMarker(throughDisconnect) == "Oct 19, 2026, 21:09:36 DISCONNECTED",
                     "the marker is the timestamp and name of the last event")
        suite.expect(OpenVPNSupport.lastEventMarker("") == nil, "an empty tail has no marker")

        // MARK: Status

        let connectedLog = OpenVPNLogState.connected(interface: "utun7", host: "vpn.example.com")
        suite.expect(OpenVPNSupport.resolveStatus(connectedLog, profiles: profiles,
                                                  interfaceHasAddress: { _ in false }) == .disconnected,
                     "CONNECTED with the named interface gone is disconnected")
        suite.expect(OpenVPNSupport.resolveStatus(connectedLog, profiles: profiles,
                                                  interfaceHasAddress: { $0 == "utun3" }) == .disconnected,
                     "another VPN's addressed interface does not make OpenVPN connected")
        suite.expect(OpenVPNSupport.resolveStatus(connectedLog, profiles: profiles,
                                                  interfaceHasAddress: { $0 == "utun7" })
                        == .connected(profileName: "Office"),
                     "the named interface with an address is connected, with a unique host's profile name")
        suite.expect(OpenVPNSupport.resolveStatus(.connected(interface: "utun7", host: "192.0.2.10"),
                                                  profiles: profiles,
                                                  interfaceHasAddress: { $0 == "utun7" })
                        == .connected(profileName: nil),
                     "two profiles sharing a host give no name")
        suite.expect(OpenVPNSupport.resolveStatus(.connected(interface: "utun7", host: "other.example"),
                                                  profiles: profiles,
                                                  interfaceHasAddress: { $0 == "utun7" })
                        == .connected(profileName: nil),
                     "an unknown host gives no name")
        suite.expect(OpenVPNSupport.resolveStatus(.connected(interface: nil, host: "vpn.example.com"),
                                                  profiles: profiles,
                                                  interfaceHasAddress: { _ in true }) == .disconnected,
                     "CONNECTED without an interface cannot be verified")
        suite.expect(OpenVPNSupport.resolveStatus(.inProgress, profiles: profiles,
                                                  interfaceHasAddress: { _ in true }) == .connecting,
                     "in progress is connecting")
        suite.expect(OpenVPNSupport.resolveStatus(.ended, profiles: profiles,
                                                  interfaceHasAddress: { _ in true }) == .disconnected,
                     "ended is disconnected")
        suite.expect(OpenVPNSupport.resolveStatus(.noEvents, profiles: profiles,
                                                  interfaceHasAddress: { _ in true }) == .disconnected,
                     "no events is disconnected")

        // MARK: Strings

        let english = FeatureStrings.openVPN(.enUS)
        for language in AppLanguage.allCases {
            let strings = FeatureStrings.openVPN(language)
            for field in Mirror(reflecting: strings).children {
                let value = (field.value as? String) ?? ""
                suite.expect(!value.trimmingCharacters(in: .whitespaces).isEmpty,
                             "\(language) \(field.label ?? "?") is not empty")
            }
            if language != .enUS {
                suite.expect(strings.pinHint != english.pinHint, "\(language) translates the PIN hint")
            }
        }

        // MARK: Commands and paths

        suite.expect(OpenVPNSupport.appExecutablePath.hasPrefix(OpenVPNSupport.appBundlePath + "/"),
                     "the executable lives inside the app bundle")

        suite.expect(OpenVPNSupport.connectArguments(profileID: "1747746310902")
                        == ["--connect-shortcut=1747746310902"],
                     "a numeric profile id becomes the connect flag")
        for bad in ["12; rm -rf", "", "abc", "12 34", "-1", "１２"] {
            suite.expect(OpenVPNSupport.connectArguments(profileID: bad) == nil,
                         "profile id \(bad.debugDescription) never reaches the command line")
        }
        suite.expect(OpenVPNSupport.disconnectArguments == ["--disconnect-shortcut"],
                     "disconnect uses the shortcut flag")
        suite.expect(OpenVPNSupport.logURL(home: URL(fileURLWithPath: "/Users/test")).path
                        == "/Users/test/Library/Application Support/OpenVPN Connect/log/ovpn.log",
                     "the live log is ovpn.log")
        suite.expect(OpenVPNSupport.logTailBytes == 65_536, "only the last 64 KB of the log is read")
        suite.expect(OpenVPNSupport.appExecutablePath
                        == "/Applications/OpenVPN Connect/OpenVPN Connect.app/Contents/MacOS/OpenVPN Connect",
                     "the app executable path")

        OpenVPNServiceTests.run(suite)
    }
}

enum OpenVPNServiceTests {
    private static let disconnectedTail = OpenVPNTests.entry("21:09:36", "EVENT: DISCONNECTED ")
    private static let connectID = "1747746310902"

    /// Every dependency of the service, recorded and controllable.
    private final class Fake {
        var installed = true
        var tail: String?
        var addressed: Set<String> = []
        var clock = Date(timeIntervalSince1970: 1_000)
        var result = BoundedProcessRunner.Result(status: 0, output: Data(), timedOut: false)
        var profileOutput = Data()
        var commands: [[String]] = []
        var logReads = 0

        func service() -> OpenVPNService {
            OpenVPNService(
                runCommand: { [self] arguments in
                    commands.append(arguments)
                    if arguments == ["--list-profiles"] {
                        return BoundedProcessRunner.Result(status: 0, output: profileOutput, timedOut: false)
                    }
                    return result
                },
                readLogTail: { [self] in logReads += 1; return tail },
                interfaceHasAddress: { [self] in addressed.contains($0) },
                appInstalled: { [self] in installed },
                now: { [self] in clock },
                background: { $0() },
                main: { $0() })
        }
    }

    private static func failed(status: Int32 = 1, timedOut: Bool = false) -> BoundedProcessRunner.Result {
        BoundedProcessRunner.Result(status: status, output: Data(), timedOut: timedOut)
    }

    static func run(_ suite: TestSuite) {
        do {
            let fake = Fake()
            fake.installed = false
            let service = fake.service()
            service.refresh()
            service.connect(profileID: connectID)
            suite.expect(service.status == .unavailable(.appMissing), "no app, no control")
            suite.expect(fake.commands.isEmpty && fake.logReads == 0,
                         "without the app nothing is run and no log is read")
        }
        do {
            let fake = Fake()
            let service = fake.service()
            service.refresh()
            suite.expect(service.status == .unavailable(.logUnreadable), "an unreadable log is reported")
        }
        do {
            let fake = Fake()
            fake.tail = disconnectedTail
            let service = fake.service()
            service.connect(profileID: "abc")
            service.connect(profileID: "1; ls")
            suite.expect(fake.commands.isEmpty, "a non-numeric profile id never reaches the command line")
        }
        do {
            let fake = Fake()
            fake.tail = disconnectedTail
            let service = fake.service()
            service.connect(profileID: connectID)
            suite.expect(fake.commands == [["--connect-shortcut=\(connectID)"]],
                         "connect passes the connect flag with the profile id")
            suite.expect(service.status == .connecting, "a started connect is connecting")

            fake.result = failed()
            service.connect(profileID: connectID)
            suite.expect(service.status == .unavailable(.commandFailed), "a failing command is reported")
            service.refresh()
            suite.expect(service.status == .unavailable(.commandFailed),
                         "the failure stays until the next successful command")
            fake.result = failed(status: 0, timedOut: true)
            service.connect(profileID: connectID)
            suite.expect(service.status == .unavailable(.commandFailed), "a timed out command is reported")
            fake.result = BoundedProcessRunner.Result(status: 0, output: Data(), timedOut: false)
            service.connect(profileID: connectID)
            suite.expect(service.status == .connecting, "a successful command clears the failure")
        }
        do {
            // The log says nothing while a PIN is pending, so a started connect is remembered.
            let fake = Fake()
            fake.tail = disconnectedTail
            let service = fake.service()
            service.connect(profileID: connectID)
            service.refresh()
            suite.expect(service.status == .connecting, "an unchanged log keeps a started connect connecting")
            fake.tail = OpenVPNTests.connectedSession
            fake.addressed = ["utun7"]
            service.refresh()
            suite.expect(service.status == .connected(profileName: nil), "a moved log takes over")
        }
        do {
            let fake = Fake()
            fake.tail = disconnectedTail
            let service = fake.service()
            service.connect(profileID: connectID)
            fake.clock = fake.clock.addingTimeInterval(121)
            service.refresh()
            suite.expect(service.status == .disconnected,
                         "a connect the log never answers stops showing connecting after 120 seconds")
        }
        do {
            let fake = Fake()
            fake.tail = disconnectedTail
            let service = fake.service()
            service.connect(profileID: connectID)
            service.disconnect()
            suite.expect(fake.commands.last == ["--disconnect-shortcut"], "disconnect passes the disconnect flag")
            suite.expect(service.status == .disconnected, "disconnecting cancels a pending connect")
        }
        do {
            let fake = Fake()
            fake.tail = OpenVPNTests.connectedSession
            fake.profileOutput = Data(OpenVPNTests.profilesJSON.utf8)
            fake.addressed = ["utun7"]
            let service = fake.service()
            service.panelDidAppear()
            suite.expect(service.profiles.count == 3, "opening the panel loads the saved profiles")
            suite.expect(service.status == .connected(profileName: "Office"),
                         "a verified tunnel shows the profile whose host it is on")
            fake.addressed = []
            service.refresh()
            suite.expect(service.status == .disconnected, "a tunnel interface that is gone is disconnected")

            let reads = fake.logReads
            service.panelDidDisappear()
            service.pollIfActive()
            suite.expect(fake.logReads == reads, "a closed panel does no polling")
        }
        do {
            let fake = Fake()
            fake.tail = disconnectedTail
            let service = fake.service()
            service.panelDidAppear()
            service.panelDidAppear()
            service.panelDidDisappear()
            let reads = fake.logReads
            service.pollIfActive()
            suite.expect(fake.logReads > reads, "polling continues while another panel is still open")
            service.panelDidDisappear()
            service.panelDidDisappear()
        }
    }
}

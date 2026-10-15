// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Combine
import Darwin

final class OmniWMWorkspaceService: ObservableObject {
    static let shared = OmniWMWorkspaceService()
    @Published private(set) var monitors: [OmniWMWorkspaceBarMonitor] = []
    @Published private(set) var isPresented = false
    /// The panel of workspace cards is open below the strip.
    @Published private(set) var isExpanded = false
    @Published private(set) var connection = OmniWMConnection.off
    @Published private(set) var pendingWorkspaceID: String?
    /// Called with `true` when the strip appears or leaves, and with `false`
    /// when only its contents changed.
    var presentationChanged: ((_ presence: Bool) -> Void)?

    private var modifierTimer: Timer?
    private var hold = OmniWMWorkspaceHold()
    private var process: Process?
    private var retry: DispatchWorkItem?
    private var commandDeadline: DispatchWorkItem?
    private var generation = UUID()
    private var hoveredDisplays = Set<String>()
    private var enabled = false
    private var icons: [String: NSImage] = [:]

    static var executable: URL? {
        let candidates = [
            URL(fileURLWithPath: "/Applications/OmniWM.app/Contents/MacOS/omniwmctl"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/OmniWM.app/Contents/MacOS/omniwmctl"),
            URL(fileURLWithPath: "/opt/homebrew/bin/omniwmctl"),
            URL(fileURLWithPath: "/usr/local/bin/omniwmctl")
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    func syncWithPreferences(active: Bool) {
        let wanted = active && (UserDefaults.standard.object(forKey: OmniWMWorkspaceSupport.preferenceKey) as? Bool ?? true)
        guard wanted != enabled else { return }
        if !wanted { stop(); return }
        enabled = true
        connection = .waiting
        connect()
    }

    func stop() {
        enabled = false
        generation = UUID()
        retry?.cancel(); retry = nil
        commandDeadline?.cancel(); commandDeadline = nil
        if let process { Self.terminate(process) }
        process = nil
        monitors = []
        pendingWorkspaceID = nil
        connection = .off
        syncModifierPolling()
    }

    func monitor(for frame: CGRect) -> OmniWMWorkspaceBarMonitor? {
        guard let id = OmniWMWorkspaceSupport.screenID(for: frame) else { return nil }
        return monitors.first { $0.id == id }
    }

    func icon(for bundleID: String?) -> NSImage? {
        guard let bundleID else { return nil }
        return icons[bundleID]
    }

    func hover(_ inside: Bool, screen: CGRect) {
        guard let id = OmniWMWorkspaceSupport.screenID(for: screen) else { return }
        if inside { hoveredDisplays.insert(id) } else { hoveredDisplays.remove(id) }
    }

    /// Option is only watched while there is something to show, so a missing
    /// or closed OmniWM costs no timer at all.
    private func syncModifierPolling() {
        let wanted = enabled && connection == .connected && monitors.contains { !$0.workspaces.isEmpty }
        if wanted, modifierTimer == nil {
            let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in self?.pollModifier() }
            timer.tolerance = 0.01
            RunLoop.main.add(timer, forMode: .common)
            modifierTimer = timer
        } else if !wanted, let timer = modifierTimer {
            timer.invalidate()
            modifierTimer = nil
            hold = OmniWMWorkspaceHold()
            hoveredDisplays.removeAll()
            setPresented(false, expanded: false)
        }
    }

    private func pollModifier() {
        let now = ProcessInfo.processInfo.systemUptime
        // Option must be the only modifier so existing multi-modifier shortcuts keep working.
        let mask: NSEvent.ModifierFlags = [.option, .command, .control, .shift]
        let held = NSEvent.modifierFlags.intersection(mask) == .option
        let presented = hold.update(held: held, hovered: !hoveredDisplays.isEmpty, now: now)
        setPresented(presented, expanded: hold.expanded)
    }

    private func setPresented(_ value: Bool, expanded: Bool) {
        guard isPresented != value || isExpanded != expanded else { return }
        isPresented = value
        isExpanded = value && expanded
        if !value { pendingWorkspaceID = nil }
        presentationChanged?(true)
    }

    private func connect() {
        guard enabled, process == nil else { return }
        guard let executable = Self.executable else {
            disconnected(.notInstalled)
            return
        }
        let current = generation
        let pipe = Pipe()
        let child = Process()
        child.executableURL = executable
        child.arguments = ["subscribe", "workspace-bar", "--reconnect", "--format", "ndjson"]
        child.standardInput = FileHandle.nullDevice
        child.standardOutput = pipe
        child.standardError = FileHandle.nullDevice
        do { try child.run() } catch {
            disconnected(.waiting)
            return
        }
        process = child
        DispatchQueue.global(qos: .utility).async { [weak self] in
            var buffer = Data()
            while true {
                let chunk = pipe.fileHandleForReading.availableData
                if chunk.isEmpty { break }
                buffer.append(chunk)
                // A broken peer must not grow the app's buffer without a newline.
                if buffer.count > 4 * 1024 * 1024 { break }
                while let newline = buffer.firstIndex(of: 10) {
                    let line = Data(buffer[..<newline])
                    buffer.removeSubrange(...newline)
                    guard let payload = OmniWMWorkspaceSupport.decode(line) else { continue }
                    DispatchQueue.main.async { [weak self] in
                        guard let self, self.enabled, self.generation == current else { return }
                        self.receive(payload)
                    }
                }
            }
            Self.terminate(child)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.enabled, self.generation == current else { return }
                self.process = nil
                self.disconnected(.waiting)
            }
        }
    }

    private func receive(_ payload: OmniWMWorkspaceBarPayload) {
        let focused = Set(monitors.flatMap(\.workspaces).filter(\.isFocused).map(\.id))
        monitors = payload.monitors
        if focused != Set(monitors.flatMap(\.workspaces).filter(\.isFocused).map(\.id)) {
            hold.switched(now: ProcessInfo.processInfo.systemUptime)
        }
        connection = .connected
        if let pendingWorkspaceID,
           monitors.flatMap(\.workspaces).contains(where: { $0.id == pendingWorkspaceID && $0.isFocused }) {
            self.pendingWorkspaceID = nil
        }
        for app in monitors.flatMap(\.workspaces).flatMap(\.apps) {
            guard let id = app.bundleId, icons[id] == nil,
                  let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id),
                  let image = NSWorkspace.shared.icon(forFile: url.path).copy() as? NSImage else { continue }
            image.size = NSSize(width: 48, height: 48)
            icons[id] = image
        }
        syncModifierPolling()
        presentationChanged?(false)
    }

    private func disconnected(_ state: OmniWMConnection) {
        monitors = []
        pendingWorkspaceID = nil
        connection = state
        syncModifierPolling()
        presentationChanged?(false)
        retry?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.connect() }
        retry = work
        // Installing OmniWM is rare; a dropped connection usually comes straight back.
        DispatchQueue.main.asyncAfter(deadline: .now() + (state == .notInstalled ? 10 : 2), execute: work)
    }

    func focus(workspace: OmniWMWorkspaceBarWorkspace) {
        guard !workspace.isFocused || pendingWorkspaceID != nil else { return }
        command(["workspace", "focus-name", workspace.rawName], workspaceID: workspace.id)
    }

    func focus(window: OmniWMWorkspaceWindowRow, in workspace: OmniWMWorkspaceBarWorkspace) {
        command(["window", "focus", window.id], workspaceID: workspace.id)
    }

    func focus(group: OmniWMWorkspaceAppGroup, in workspace: OmniWMWorkspaceBarWorkspace, cycling: Bool) {
        guard let window = group.target(cycling: cycling) else { return }
        command(["window", "focus", window.id], workspaceID: workspace.id)
    }

    private func command(_ arguments: [String], workspaceID: String) {
        guard enabled, let executable = Self.executable else { return }
        pendingWorkspaceID = workspaceID
        let child = Process()
        child.executableURL = executable
        child.arguments = arguments
        child.standardInput = FileHandle.nullDevice
        child.standardOutput = FileHandle.nullDevice
        child.standardError = FileHandle.nullDevice
        let current = generation
        child.terminationHandler = { [weak self] child in
            DispatchQueue.main.async {
                guard let self, self.enabled, self.generation == current else { return }
                // The highlight returns to where OmniWM really is.
                if child.terminationStatus != 0 {
                    self.pendingWorkspaceID = nil
                    NSSound.beep()
                }
            }
        }
        do { try child.run() } catch {
            pendingWorkspaceID = nil
            NSSound.beep()
            return
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) { Self.terminate(child) }
        commandDeadline?.cancel()
        let deadline = DispatchWorkItem { [weak self] in self?.pendingWorkspaceID = nil }
        commandDeadline = deadline
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: deadline)
    }

    private static func terminate(_ child: Process) {
        guard child.isRunning else { return }
        child.terminate()
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            if child.isRunning { kill(child.processIdentifier, SIGKILL) }
        }
    }
}

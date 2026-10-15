// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Combine
import Darwin

final class OmniWMWorkspaceService: ObservableObject {
    static let shared = OmniWMWorkspaceService()
    @Published private(set) var monitors: [OmniWMWorkspaceBarMonitor] = []
    @Published private(set) var isPresented = false
    @Published private(set) var status = "Connecting to OmniWM…"
    @Published private(set) var pendingWorkspaceID: String?
    var presentationChanged: (() -> Void)?

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
        connect()
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in self?.pollModifier() }
        RunLoop.main.add(timer, forMode: .common)
        modifierTimer = timer
    }

    func stop() {
        enabled = false
        generation = UUID()
        retry?.cancel(); retry = nil
        commandDeadline?.cancel(); commandDeadline = nil
        modifierTimer?.invalidate(); modifierTimer = nil
        hold = OmniWMWorkspaceHold()
        hoveredDisplays.removeAll()
        if let process { Self.terminate(process) }
        process = nil
        monitors = []
        pendingWorkspaceID = nil
        setPresented(false)
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

    private func pollModifier() {
        let now = ProcessInfo.processInfo.systemUptime
        // Option must be the only modifier so existing multi-modifier shortcuts keep working.
        let mask: NSEvent.ModifierFlags = [.option, .command, .control, .shift]
        let held = NSEvent.modifierFlags.intersection(mask) == .option
        setPresented(hold.update(held: held, hovered: !hoveredDisplays.isEmpty, now: now))
    }

    private func setPresented(_ value: Bool) {
        guard isPresented != value else { return }
        isPresented = value
        presentationChanged?()
    }

    private func connect() {
        guard enabled, process == nil else { return }
        guard let executable = Self.executable else {
            disconnected("OmniWM is not installed")
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
            disconnected(error.localizedDescription)
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
                self.disconnected("OmniWM disconnected; reconnecting…")
            }
        }
    }

    private func receive(_ payload: OmniWMWorkspaceBarPayload) {
        monitors = payload.monitors
        status = monitors.isEmpty ? "No OmniWM workspaces" : ""
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
        presentationChanged?()
    }

    private func disconnected(_ message: String) {
        monitors = []
        status = message
        pendingWorkspaceID = nil
        presentationChanged?()
        retry?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.connect() }
        retry = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
    }

    func focus(workspace: OmniWMWorkspaceBarWorkspace) {
        command(["workspace", "focus-name", workspace.rawName], workspaceID: workspace.id)
    }

    func focus(app: OmniWMWorkspaceBarApp, workspaceID: String) {
        guard let window = app.allWindows.first(where: \.isFocused) ?? app.allWindows.first else { return }
        command(["window", "focus", window.id], workspaceID: workspaceID)
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
                if child.terminationStatus != 0 {
                    self.pendingWorkspaceID = nil
                    self.status = "OmniWM focus failed"
                }
            }
        }
        do { try child.run() } catch {
            pendingWorkspaceID = nil
            status = error.localizedDescription
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

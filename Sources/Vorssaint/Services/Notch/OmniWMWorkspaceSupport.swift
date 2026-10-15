// SPDX-License-Identifier: GPL-3.0-or-later
// Workspace payload models adapted from Atoll (GPL-3.0-or-later).

import AppKit

struct OmniWMWorkspaceBarWindow: Decodable, Identifiable, Equatable {
    let id: String
    let title: String
    let isFocused: Bool
}

struct OmniWMWorkspaceBarApp: Decodable, Identifiable {
    let id: String
    let appName: String
    let bundleId: String?
    let isFocused: Bool
    let windowCount: Int
    let allWindows: [OmniWMWorkspaceBarWindow]
}

struct OmniWMWorkspaceBarWorkspace: Decodable, Identifiable {
    let id: String
    let rawName: String
    let displayName: String
    let number: Int?
    let isFocused: Bool
    /// OmniWM sends these under `windows`, but each entry is an app with its own window list.
    let apps: [OmniWMWorkspaceBarApp]

    private enum CodingKeys: String, CodingKey {
        case id, rawName, displayName, number, isFocused
        case apps = "windows"
    }

    var isOccupied: Bool { !apps.isEmpty }
}

struct OmniWMWorkspaceBarMonitor: Decodable, Identifiable {
    let id: String
    let name: String
    let showLabels: Bool
    let workspaces: [OmniWMWorkspaceBarWorkspace]
}

struct OmniWMWorkspaceBarPayload: Decodable {
    let interactionMonitorId: String?
    let monitors: [OmniWMWorkspaceBarMonitor]
}

struct OmniWMWorkspaceBarResult: Decodable {
    let payload: OmniWMWorkspaceBarPayload
}

struct OmniWMWorkspaceBarResponse: Decodable {
    let ok: Bool
    let result: OmniWMWorkspaceBarResult?
}

/// One icon per app: OmniWM lists every window of an app as its own entry,
/// which drew two identical Safari icons side by side.
struct OmniWMWorkspaceAppGroup: Identifiable {
    let id: String
    let appName: String
    let bundleId: String?
    let windows: [OmniWMWorkspaceBarWindow]
    let isFocused: Bool

    static func groups(in workspace: OmniWMWorkspaceBarWorkspace) -> [OmniWMWorkspaceAppGroup] {
        var order: [String] = []
        var grouped: [String: (first: OmniWMWorkspaceBarApp, windows: [OmniWMWorkspaceBarWindow], focused: Bool)] = [:]
        for app in workspace.apps {
            let key = app.bundleId ?? app.appName
            let windows = app.allWindows.isEmpty
                ? [OmniWMWorkspaceBarWindow(id: app.id, title: app.appName, isFocused: app.isFocused)]
                : app.allWindows
            if var entry = grouped[key] {
                entry.windows += windows
                entry.focused = entry.focused || app.isFocused
                grouped[key] = entry
            } else {
                order.append(key)
                grouped[key] = (app, windows, app.isFocused)
            }
        }
        return order.compactMap { key in
            grouped[key].map {
                OmniWMWorkspaceAppGroup(id: $0.first.id, appName: $0.first.appName, bundleId: $0.first.bundleId,
                                        windows: $0.windows, isFocused: $0.focused || $0.windows.contains(where: \.isFocused))
            }
        }
    }

    /// In the workspace on screen a repeat click walks the app's windows;
    /// elsewhere it returns to the window that workspace last focused.
    func target(cycling: Bool) -> OmniWMWorkspaceBarWindow? {
        guard let current = windows.firstIndex(where: \.isFocused) else { return windows.first }
        return cycling ? windows[(current + 1) % windows.count] : windows[current]
    }
}

enum OmniWMConnection: Equatable {
    case off, notInstalled, waiting, connected
}

enum OmniWMWorkspaceSupport {
    static let preferenceKey = "local.omniWMWorkspaceBar"

    static func decode(_ data: Data) -> OmniWMWorkspaceBarPayload? {
        guard let response = try? JSONDecoder().decode(OmniWMWorkspaceBarResponse.self, from: data),
              response.ok else { return nil }
        return response.result?.payload
    }

    static func screenID(for frame: CGRect) -> String? {
        guard let screen = NSScreen.screens.first(where: { $0.frame == frame }),
              let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
        return "display:\(number.uint32Value)"
    }

    static func size(_ monitor: OmniWMWorkspaceBarMonitor?, geometry: NotchGeometry) -> CGSize {
        OmniWMWorkspaceLayout(monitor: monitor, geometry: geometry).size
    }

    static func label(for workspace: OmniWMWorkspaceBarWorkspace, showLabels: Bool) -> String {
        showLabels ? workspace.displayName : workspace.number.map(String.init) ?? workspace.displayName
    }

    static func caption(_ connection: OmniWMConnection) -> String {
        let usage = "Hold ⌥ to see workspaces and switch between them."
        switch connection {
        case .off: return usage
        case .connected: return usage + " Connected to OmniWM."
        case .waiting: return "Waiting for OmniWM. Open it and turn on IPC in its settings."
        case .notInstalled: return "Install OmniWM to use the workspace strip."
        }
    }
}

struct OmniWMWorkspaceHold {
    private var pressedAt: TimeInterval?
    private var releasedAt: TimeInterval?
    private(set) var presented = false

    mutating func update(held: Bool, hovered: Bool, now: TimeInterval) -> Bool {
        if held {
            releasedAt = nil
            if pressedAt == nil { pressedAt = now }
            if now - (pressedAt ?? now) >= 0.2 { presented = true }
        } else {
            pressedAt = nil
            if releasedAt == nil { releasedAt = now }
            if !hovered, now - (releasedAt ?? now) >= 0.6 { presented = false }
        }
        return presented
    }
}

/// Each workspace is a pill holding its apps' icons. The pills split across
/// the camera where the two halves come out closest in width, so neither wing
/// carries dead space for the other.
struct OmniWMWorkspaceLayout {
    let pillHeight: CGFloat
    /// Concentric with the island's lower corners, so a pill reads as nested
    /// in the island rather than set on it. A capsule island keeps capsules.
    let cornerRadius: CGFloat
    let endInset: CGFloat
    let cameraGap: CGFloat
    let wingWidth: CGFloat
    let size: CGSize
    let leading: [OmniWMWorkspaceBarWorkspace]
    let trailing: [OmniWMWorkspaceBarWorkspace]
    let showLabels: Bool
    static let spacing: CGFloat = 4
    static let pillPadding: CGFloat = 8
    static let iconSpacing: CGFloat = 4
    /// Every pill shows as many icons, so a switch never resizes the island.
    static let iconCap = 3
    static let overflowSize: CGFloat = 9

    var textSize: CGFloat { min(12, pillHeight - 8) }
    var iconSize: CGFloat { max(11, min(16, pillHeight - 10)) }

    init(monitor: OmniWMWorkspaceBarMonitor?, geometry: NotchGeometry) {
        pillHeight = max(18, min(26, geometry.stripBodyHeight - 6))
        let island = NotchLayout.surfaceRadius(height: geometry.stripHeight)
        cornerRadius = geometry.floats ? pillHeight / 2
            : max(6, min(pillHeight / 2, island - (geometry.stripHeight - pillHeight) / 2))
        cameraGap = geometry.isNotched ? geometry.compactActivityCameraGap : NotchCapsuleLayout.spacing
        let outer = geometry.floats
            ? NotchCapsuleLayout.side(geometry) + NotchCapsuleLayout.endPadding
            : geometry.compactActivityEdgeInset(boxHeight: pillHeight, radius: cornerRadius)
        let maximum = max(0, geometry.screen.width - 24)
        endInset = min(outer, max(0, (maximum - cameraGap) / 2))
        showLabels = monitor?.showLabels == true
        let workspaces = monitor?.workspaces ?? []
        let height = pillHeight
        let labels = showLabels
        let widths = workspaces.map { Self.pillWidth($0, showLabels: labels, height: height) }
        // The split point that keeps the wider half narrowest.
        var best = (index: 0, width: CGFloat.infinity)
        for index in 0...workspaces.count {
            let width = max(Self.rowWidth(widths[..<index]), Self.rowWidth(widths[index...]))
            if width < best.width { best = (index, width) }
        }
        leading = Array(workspaces[..<best.index])
        trailing = Array(workspaces[best.index...])
        let content = (workspaces.isEmpty ? 0 : best.width) + NotchLayout.compactEdgeGap
        let width = min(maximum, content * 2 + cameraGap + endInset * 2)
        wingWidth = max(0, (width - cameraGap - endInset * 2) / 2)
        size = CGSize(width: width, height: geometry.stripHeight)
    }

    func pillWidth(_ workspace: OmniWMWorkspaceBarWorkspace) -> CGFloat {
        Self.pillWidth(workspace, showLabels: showLabels, height: pillHeight)
    }

    func rowWidth(_ workspaces: [OmniWMWorkspaceBarWorkspace]) -> CGFloat {
        Self.rowWidth(workspaces.map(pillWidth)[...])
    }

    /// Measured with the focused weight, so focus moving never changes a width.
    static func pillWidth(_ workspace: OmniWMWorkspaceBarWorkspace, showLabels: Bool, height: CGFloat) -> CGFloat {
        let name = OmniWMWorkspaceSupport.label(for: workspace, showLabels: showLabels)
        let textSize = min(12, height - 8)
        let iconSize = max(11, min(16, height - 10))
        var width = pillPadding * 2 + measure(name, size: textSize)
        let apps = OmniWMWorkspaceAppGroup.groups(in: workspace).count
        let shown = min(apps, iconCap)
        width += CGFloat(shown) * (iconSpacing + iconSize)
        if apps > shown { width += iconSpacing + measure("+\(apps - shown)", size: overflowSize) }
        // A lone number stays a round pill rather than a sliver.
        return max(height, ceil(width))
    }

    private static func measure(_ text: String, size: CGFloat) -> CGFloat {
        let font = NSFont.systemFont(ofSize: size, weight: .semibold)
        return ceil((text as NSString).size(withAttributes: [.font: font]).width) + NotchCapsuleLayout.air
    }

    private static func rowWidth(_ widths: ArraySlice<CGFloat>) -> CGFloat {
        widths.reduce(0, +) + CGFloat(max(0, widths.count - 1)) * spacing
    }
}

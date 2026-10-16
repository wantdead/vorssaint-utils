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

/// Holding Option shows the strip, however long the hold. A double tap opens
/// the strip with the panel below it, which stays until Option is tapped
/// again, something in it is clicked, or the pointer leaves it after a visit.
/// Left untouched, it closes after a few seconds.
struct OmniWMWorkspaceHold {
    static let showDelay: TimeInterval = 0.2
    static let releaseGrace: TimeInterval = 0.6
    /// The longest press that still counts as a tap.
    static let tapLimit: TimeInterval = 0.25
    /// From the first tap's release to the second press.
    static let doubleTapGap: TimeInterval = 0.35
    static let panelIdle: TimeInterval = 4
    static let panelLeaveGrace: TimeInterval = 0.4
    private var pressedAt: TimeInterval?
    private var releasedAt: TimeInterval?
    private var tapReleasedAt: TimeInterval?
    /// The press that opened the panel is not also a tap that closes it.
    private var pressOpenedPanel = false
    private var panelOpenedAt: TimeInterval?
    private var panelVisited = false
    private var panelLeftAt: TimeInterval?
    private(set) var presented = false
    private(set) var expanded = false

    /// `lastInput` is when a key or mouse button last went down: Option typing
    /// a character, or an Option-click, is not a tap.
    mutating func update(held: Bool, hovered: Bool, now: TimeInterval,
                         lastInput: TimeInterval = -.infinity) -> Bool {
        if held {
            if pressedAt == nil {
                pressedAt = now
                releasedAt = nil
                if !expanded, let tap = tapReleasedAt, now - tap <= Self.doubleTapGap {
                    open(now)
                    pressOpenedPanel = true
                }
                tapReleasedAt = nil
            }
            if now - (pressedAt ?? now) >= Self.showDelay { presented = true }
        } else if let pressed = pressedAt {
            pressedAt = nil
            releasedAt = now
            let tapped = now - pressed < Self.tapLimit && lastInput < pressed
            if tapped, !pressOpenedPanel {
                if expanded { dismiss(); return presented }
                tapReleasedAt = now
            }
            pressOpenedPanel = false
        }
        if expanded {
            if hovered {
                panelVisited = true
                panelLeftAt = nil
            } else if panelVisited {
                if panelLeftAt == nil { panelLeftAt = now }
                if now - (panelLeftAt ?? now) >= Self.panelLeaveGrace { dismiss() }
            } else if pressedAt == nil, let opened = panelOpenedAt,
                      now - max(opened, releasedAt ?? opened) >= Self.panelIdle {
                dismiss()
            }
        } else if pressedAt == nil, let releasedAt, !hovered, now - releasedAt >= Self.releaseGrace {
            presented = false
        }
        return presented
    }

    mutating func dismiss() {
        presented = false
        expanded = false
        panelOpenedAt = nil
        panelVisited = false
        panelLeftAt = nil
        tapReleasedAt = nil
    }

    private mutating func open(_ now: TimeInterval) {
        presented = true
        expanded = true
        panelOpenedAt = now
        panelVisited = false
        panelLeftAt = nil
    }
}

/// Each workspace is a pill holding its apps' icons. The pills split across
/// the camera where the two halves come out closest in width, and each wing is
/// only as wide as its own pills: the island reaches further toward the wider
/// half, like a notice, instead of padding the narrower one with dead space.
struct OmniWMWorkspaceLayout {
    let pillHeight: CGFloat
    /// Concentric with the island's lower corners, so a pill reads as nested
    /// in the island rather than set on it. A capsule island keeps capsules.
    let cornerRadius: CGFloat
    let endInset: CGFloat
    let cameraGap: CGFloat
    let leadingWidth: CGFloat
    let trailingWidth: CGFloat
    /// How far the strip's centre sits right of the camera's.
    let shift: CGFloat
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
        cameraGap = geometry.isNotched ? geometry.compactActivityCameraGap : 0
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
        // Without a physical camera there is nothing to split around: one
        // centred row.
        if !geometry.isNotched {
            leading = workspaces
            trailing = []
            let width = min(maximum, Self.rowWidth(widths[...]) + endInset * 2)
            leadingWidth = max(0, width - endInset * 2)
            trailingWidth = 0
            shift = 0
            size = CGSize(width: width, height: geometry.stripHeight)
            return
        }
        // The split point that keeps the wider half narrowest, so the island
        // strays as little as it can from the camera.
        var best = (index: 0, width: CGFloat.infinity)
        for index in 0...workspaces.count {
            let width = max(Self.rowWidth(widths[..<index]), Self.rowWidth(widths[index...]))
            if width < best.width { best = (index, width) }
        }
        leading = Array(workspaces[..<best.index])
        trailing = Array(workspaces[best.index...])
        // An empty or short wing still reaches past the camera, so the island
        // covers it; capped at half the screen around it, so neither end leaves.
        let floor = max(NotchLayout.compactEdgeGap, (geometry.cameraWidth - cameraGap) / 2 - endInset)
        let cap = max(0, (maximum - cameraGap) / 2 - endInset)
        func wing(_ part: ArraySlice<CGFloat>) -> CGFloat {
            min(cap, max(floor, Self.rowWidth(part) + NotchLayout.compactEdgeGap))
        }
        leadingWidth = wing(widths[..<best.index])
        trailingWidth = wing(widths[best.index...])
        shift = (trailingWidth - leadingWidth) / 2
        size = CGSize(width: leadingWidth + cameraGap + trailingWidth + endInset * 2, height: geometry.stripHeight)
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

/// The strip with a short list hanging below it: one line per workspace that
/// holds windows, plus the one on screen, naming its apps. The strip above
/// already lists every workspace. Four or more lines split into two columns,
/// filled top to bottom, so the panel stays as wide as the strip.
struct OmniWMWorkspacePanelLayout {
    let strip: OmniWMWorkspaceLayout
    let entries: [OmniWMWorkspaceBarWorkspace]
    let columns: [[OmniWMWorkspaceBarWorkspace]]
    let columnWidth: CGFloat
    let listHeight: CGFloat
    let size: CGSize
    static let rowHeight: CGFloat = 26
    static let rowSpacing: CGFloat = 2
    static let rowRadius: CGFloat = 8
    static let columnSpacing: CGFloat = 10
    static let minimumColumnWidth: CGFloat = 220
    static let horizontalInset: CGFloat = 16
    static let topGap: CGFloat = 6
    static let bottomInset: CGFloat = 10
    /// Lines beyond this scroll inside their column.
    static let maximumLines = 6
    static let iconSize: CGFloat = 18
    static let iconCap = 4

    init(monitor: OmniWMWorkspaceBarMonitor?, geometry: NotchGeometry) {
        strip = OmniWMWorkspaceLayout(monitor: monitor, geometry: geometry)
        let listed = (monitor?.workspaces ?? []).filter { $0.isOccupied || $0.isFocused }
        entries = listed
        let count = listed.count >= 4 ? 2 : 1
        let lines = max(1, Int((Double(listed.count) / Double(count)).rounded(.up)))
        columns = stride(from: 0, to: listed.count, by: lines).map { Array(listed[$0..<min($0 + lines, listed.count)]) }
        let maximum = max(0, geometry.screen.width - 24)
        let minimum = CGFloat(count) * Self.minimumColumnWidth + CGFloat(count - 1) * Self.columnSpacing
            + Self.horizontalInset * 2
        let shown = CGFloat(min(lines, Self.maximumLines))
        listHeight = shown * Self.rowHeight + max(0, shown - 1) * Self.rowSpacing
        let height = geometry.stripHeight + Self.topGap + listHeight + Self.bottomInset
        // The open island's taller outline has wider shoulders than the strip
        // alone, so it grows past the strip enough for the end pills to keep
        // their gap from its sides.
        let shoulders = geometry.floats ? 0
            : max(0, NotchLayout.shoulder(height: height) + NotchLayout.compactEdgeGap - strip.endInset) * 2
        let width = min(maximum, max(strip.size.width + shoulders, minimum))
        columnWidth = max(0, (width - Self.horizontalInset * 2 - CGFloat(count - 1) * Self.columnSpacing) / CGFloat(count))
        size = CGSize(width: width, height: height)
    }

    /// "Mail, Calendar", or "Safari ×2" for an app with several windows.
    static func names(_ workspace: OmniWMWorkspaceBarWorkspace) -> String {
        OmniWMWorkspaceAppGroup.groups(in: workspace)
            .map { $0.windows.count > 1 ? "\($0.appName) ×\($0.windows.count)" : $0.appName }
            .joined(separator: ", ")
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
// Workspace payload models adapted from Atoll (GPL-3.0-or-later).

import AppKit

struct OmniWMWorkspaceBarWindow: Decodable, Identifiable {
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

struct OmniWMWorkspaceLayout {
    let controlSide: CGFloat
    let endInset: CGFloat
    let cameraGap: CGFloat
    let wingWidth: CGFloat
    let size: CGSize
    static let spacing: CGFloat = 4
    static let cornerRadius: CGFloat = 9

    init(monitor: OmniWMWorkspaceBarMonitor?, geometry: NotchGeometry) {
        controlSide = max(16, min(28, geometry.stripBodyHeight - 4))
        cameraGap = geometry.isNotched ? geometry.compactActivityCameraGap : NotchCapsuleLayout.spacing
        let outer = geometry.floats
            ? NotchCapsuleLayout.side(geometry) + NotchCapsuleLayout.endPadding
            : geometry.compactActivityEdgeInset(boxHeight: controlSide, radius: Self.cornerRadius)
        let maximum = max(0, geometry.screen.width - 24)
        endInset = min(outer, max(0, (maximum - cameraGap) / 2))
        // Keep the surface stable while focus changes; overflow scrolls inside its wings.
        let count = min(6, max(4, monitor?.workspaces.count ?? 0))
        let desired = CGFloat(count) * controlSide + CGFloat(count - 1) * Self.spacing
            + NotchLayout.compactEdgeGap * 2
        let width = min(maximum, desired * 2 + cameraGap + endInset * 2)
        wingWidth = max(0, (width - cameraGap - endInset * 2) / 2)
        size = CGSize(width: width, height: geometry.stripHeight)
    }
}

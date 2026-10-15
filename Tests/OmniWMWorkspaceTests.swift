// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

enum OmniWMWorkspaceTests {
    static func run(_ suite: TestSuite) {
        let event = #"""
        {"ok":true,"result":{"payload":{"interactionMonitorId":"display:1","monitors":[
          {"id":"display:1","name":"Built-in","showLabels":true,"workspaces":[
            {"id":"workspace:dev","rawName":"dev's workspace","displayName":"Development","number":1,"isFocused":true,
             "windows":[{"id":"app:terminal","appName":"Terminal","bundleId":"com.apple.Terminal","isFocused":true,"windowCount":1,
                         "allWindows":[{"id":"window:7","title":"Example","isFocused":true}]}]}]},
          {"id":"display:2","name":"External","showLabels":false,"workspaces":[]}]}}}
        """#
        let payload = OmniWMWorkspaceSupport.decode(Data(event.utf8))
        suite.expect(payload?.monitors.count == 2, "the stream preserves each monitor rather than combining their workspaces")
        let monitor = payload?.monitors.first
        let workspace = monitor?.workspaces.first
        suite.expect(workspace?.rawName == "dev's workspace" && workspace?.apps.first?.allWindows.first?.id == "window:7",
                     "workspace names stay intact and OmniWM's nested windows field decodes as apps")
        suite.expect(OmniWMWorkspaceSupport.decode(Data(#"{"ok":true,"result":{}}"#.utf8)) == nil,
                     "subscribe acknowledgements do not replace the last workspace snapshot")
        suite.expect(OmniWMWorkspaceSupport.decode(Data(#"{"ok":false}"#.utf8)) == nil
                     && OmniWMWorkspaceSupport.decode(Data("broken".utf8)) == nil,
                     "error and malformed envelopes do not become workspace snapshots")
        let geometry = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 1440, height: 900), safeAreaTop: 32, cameraWidth: 200)
        let size = OmniWMWorkspaceSupport.size(monitor, geometry: geometry)
        suite.expect(size.width > geometry.cameraWidth && size.width <= geometry.screen.width - 24
                     && size.height == geometry.stripHeight, "workspace bars retain the camera gap and stay within the display")
        let native = OmniWMWorkspaceLayout(monitor: monitor, geometry: geometry)
        suite.expect(native.cameraGap == geometry.compactActivityCameraGap
                     && native.controlSide <= 28 && native.size.height == geometry.stripHeight,
                     "workspace controls use the native camera gap, compact height and control size")
        suite.expect(native.endInset == geometry.compactActivityEdgeInset(boxHeight: native.controlSide, radius: 9),
                     "the outer controls clear the same silhouette curve as native island strips")
        let capsule = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 1440, height: 900), safeAreaTop: 0, cameraWidth: 0,
                                    silhouette: .capsule)
        let floating = OmniWMWorkspaceLayout(monitor: monitor, geometry: capsule)
        suite.expect(floating.cameraGap == NotchCapsuleLayout.spacing
                     && floating.endInset == NotchCapsuleLayout.side(capsule) + NotchCapsuleLayout.endPadding,
                     "a floating island uses native capsule padding without reserving a nonexistent camera")
        let tiny = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 300, height: 500), safeAreaTop: 0, cameraWidth: 0)
        suite.expect(OmniWMWorkspaceSupport.size(monitor, geometry: tiny).width <= 276,
                     "a long workspace label cannot widen the island past a narrow display")
        var hold = OmniWMWorkspaceHold()
        suite.expect(!hold.update(held: true, hovered: false, now: 0)
                     && !hold.update(held: true, hovered: false, now: 0.19)
                     && hold.update(held: true, hovered: false, now: 0.21), "a short Option tap does not show the bar")
        suite.expect(hold.update(held: false, hovered: false, now: 0.3)
                     && hold.update(held: false, hovered: false, now: 0.8)
                     && hold.update(held: false, hovered: true, now: 1.0), "release grace lets the pointer reach and retain the bar")
        suite.expect(!hold.update(held: false, hovered: false, now: 1.01), "leaving after the grace period restores the island")
        hold = OmniWMWorkspaceHold()
        suite.expect(!hold.update(held: true, hovered: false, now: 2)
                     && !hold.update(held: false, hovered: false, now: 2.1)
                     && !hold.update(held: true, hovered: false, now: 2.2), "separate Option taps never accumulate into a hold")
    }
}

// Existing island contracts exercise the upstream presentation with the local bar disabled.
extension NotchDestinationContract.Service { var showsOmniWMWorkspaceBar: Bool { false } }
extension NotchHoverTests.Service { var showsOmniWMWorkspaceBar: Bool { false } }
extension NotchMirrorContract.Service { var showsOmniWMWorkspaceBar: Bool { false } }
extension NotchMusicVisibilityTests.Service { var showsOmniWMWorkspaceBar: Bool { false } }
extension NotchPresentationRefreshContract.Service { var showsOmniWMWorkspaceBar: Bool { false } }

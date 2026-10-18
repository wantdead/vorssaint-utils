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
                     && native.pillHeight <= 26 && native.size.height == geometry.stripHeight,
                     "workspace pills use the native camera gap and fit the compact height")
        suite.expect(native.endInset == geometry.compactActivityEdgeInset(boxHeight: native.pillHeight,
                                                                          radius: native.cornerRadius),
                     "the outer controls clear the same silhouette curve as native island strips")
        let capsule = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 1440, height: 900), safeAreaTop: 0, cameraWidth: 0,
                                    silhouette: .capsule)
        let floating = OmniWMWorkspaceLayout(monitor: monitor, geometry: capsule)
        suite.expect(floating.cameraGap == 0
                     && floating.endInset == NotchCapsuleLayout.side(capsule) + NotchCapsuleLayout.endPadding,
                     "a floating island uses native capsule padding without reserving a nonexistent camera")
        let inset = (geometry.stripHeight - native.pillHeight) / 2
        suite.expect(native.cornerRadius < native.pillHeight / 2
                     && abs(native.cornerRadius - (NotchLayout.surfaceRadius(height: geometry.stripHeight) - inset)) < 0.5,
                     "beside a camera, pill corners follow the island's own corners")
        suite.expect(floating.cornerRadius == floating.pillHeight / 2, "a capsule island keeps capsule pills")
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
                     && !hold.update(held: true, hovered: false, now: 2.6)
                     && !hold.update(held: false, hovered: false, now: 2.7), "taps far apart show nothing")
        grouping(suite)
        sizing(suite, geometry: geometry)
        stages(suite)
        panel(suite, geometry: geometry)
    }

    /// Taps Option at `time` for 0.1 s.
    private static func tap(_ hold: inout OmniWMWorkspaceHold, at time: TimeInterval, lastInput: TimeInterval = -.infinity) {
        _ = hold.update(held: true, hovered: false, now: time)
        _ = hold.update(held: false, hovered: false, now: time + 0.1, lastInput: lastInput)
    }

    private static func stages(_ suite: TestSuite) {
        var hold = OmniWMWorkspaceHold()
        _ = hold.update(held: true, hovered: false, now: 0)
        _ = hold.update(held: true, hovered: true, now: 3)
        suite.expect(hold.presented && !hold.expanded, "holding Option shows the strip alone, however long, even under the pointer")
        _ = hold.update(held: false, hovered: true, now: 3.1)
        _ = hold.update(held: false, hovered: true, now: 5)
        suite.expect(hold.presented && !hold.expanded, "resting the pointer on the strip keeps it without opening the panel")

        hold = OmniWMWorkspaceHold()
        tap(&hold, at: 0)
        _ = hold.update(held: true, hovered: false, now: 0.3)
        suite.expect(hold.presented && hold.expanded, "a double tap opens the strip and the panel at once")
        _ = hold.update(held: false, hovered: false, now: 0.4)
        _ = hold.update(held: false, hovered: false, now: 4.3)
        suite.expect(hold.expanded, "the panel waits for the pointer after the second tap")
        _ = hold.update(held: false, hovered: false, now: 4.41)
        suite.expect(!hold.presented && !hold.expanded, "a panel left untouched closes after a few seconds")

        hold = OmniWMWorkspaceHold()
        tap(&hold, at: 0)
        tap(&hold, at: 0.3)
        _ = hold.update(held: false, hovered: true, now: 1)
        _ = hold.update(held: false, hovered: true, now: 9)
        suite.expect(hold.expanded, "the panel stays while the pointer is over it")
        _ = hold.update(held: false, hovered: false, now: 9.1)
        _ = hold.update(held: false, hovered: false, now: 9.4)
        suite.expect(hold.expanded, "a pointer slipping off briefly keeps the panel")
        _ = hold.update(held: false, hovered: false, now: 9.51)
        suite.expect(!hold.expanded, "moving the pointer away after a visit closes the panel")

        hold = OmniWMWorkspaceHold()
        tap(&hold, at: 0)
        tap(&hold, at: 0.3)
        tap(&hold, at: 1.5)
        suite.expect(!hold.presented && !hold.expanded, "tapping Option again closes the panel")
        tap(&hold, at: 1.8)
        suite.expect(!hold.expanded, "the tap that closed the panel does not start another double tap")

        hold = OmniWMWorkspaceHold()
        tap(&hold, at: 0)
        tap(&hold, at: 0.3)
        _ = hold.update(held: true, hovered: false, now: 1)
        _ = hold.update(held: false, hovered: false, now: 1.5)
        suite.expect(hold.expanded, "holding Option over an open panel does not close it")
        hold.dismiss()
        suite.expect(!hold.presented && !hold.expanded, "a click in the panel closes it")

        hold = OmniWMWorkspaceHold()
        tap(&hold, at: 0, lastInput: 0.05)
        _ = hold.update(held: true, hovered: false, now: 0.3)
        suite.expect(!hold.expanded, "Option typing a character is not the first tap")
        hold = OmniWMWorkspaceHold()
        _ = hold.update(held: true, hovered: false, now: 0)
        _ = hold.update(held: false, hovered: false, now: 0.3)
        _ = hold.update(held: true, hovered: false, now: 0.5)
        suite.expect(!hold.expanded, "a press too long to be a tap does not start a double tap")
    }

    private static func panel(_ suite: TestSuite, geometry: NotchGeometry) {
        let busy = monitor([
            ("1", false, [app("a", "Safari", bundle: "s", windows: [("w1", false), ("w2", true)])]),
            ("2", true, []),
            ("3", false, []),
            ("4", false, [app("b", "Mail", bundle: "m", windows: [("w3", false)]),
                          app("c", "Calendar", bundle: "c", windows: [("w4", false)])]),
            ("5", false, [app("d", "Zed", bundle: "z", windows: [("w5", false)])]),
            ("6", false, [app("e", "Gemini", bundle: "g", windows: [("w6", false)])])
        ])
        let layout = OmniWMWorkspacePanelLayout(monitor: busy, geometry: geometry)
        suite.expect(layout.entries.map(\.id) == ["1", "2", "4", "5", "6"],
                     "the list names workspaces with windows and the one on screen, not every empty one")
        suite.expect(layout.columns.map { $0.map(\.id) } == [["1", "2", "4"], ["5", "6"]],
                     "four or more lines split into two columns, filled top to bottom")
        suite.expect(layout.size.width >= layout.strip.size.width && layout.size.width <= geometry.screen.width - 24
                     && layout.size.height > layout.strip.size.height,
                     "the panel grows down from the strip and stays within the display")
        // The open outline's side, at the strip's height, against the strip's end pill.
        let side = (layout.size.width - layout.strip.size.width) / 2 + layout.strip.endInset
        suite.expect(side >= NotchLayout.shoulder(height: layout.size.height) + NotchLayout.compactEdgeGap,
                     "the strip's end pills keep their gap from the open island's wider shoulders")
        let wide = OmniWMWorkspaceLayout(monitor: busy, geometry: geometry).size.width
            + max(0, NotchLayout.shoulder(height: layout.size.height) + NotchLayout.compactEdgeGap
                  - layout.strip.endInset) * 2
        suite.expect(layout.size.width <= max(wide, 2 * OmniWMWorkspacePanelLayout.minimumColumnWidth
                                               + OmniWMWorkspacePanelLayout.columnSpacing
                                               + 2 * OmniWMWorkspacePanelLayout.horizontalInset),
                     "more workspaces make the list taller, not wider")
        suite.expect(OmniWMWorkspacePanelLayout.names(busy!.workspaces[0]) == "Safari ×2"
                     && OmniWMWorkspacePanelLayout.names(busy!.workspaces[3]) == "Mail, Calendar",
                     "a line names its apps once each, counting extra windows")
        let few = OmniWMWorkspacePanelLayout(monitor: monitor([("1", true, []), ("2", false, [])]), geometry: geometry)
        suite.expect(few.columns.count == 1 && few.size.height < layout.size.height,
                     "a short list keeps one column")
        let many = monitor((1...20).map { ("\($0)", $0 == 1, [app("x\($0)", "X", bundle: "x", windows: [("w\($0)", false)])]) })
        let capped = OmniWMWorkspacePanelLayout(monitor: many, geometry: geometry)
        let lines = CGFloat(OmniWMWorkspacePanelLayout.maximumLines)
        suite.expect(capped.listHeight == lines * OmniWMWorkspacePanelLayout.rowHeight
                     + (lines - 1) * OmniWMWorkspacePanelLayout.rowSpacing,
                     "a long list scrolls instead of reaching down the screen")
    }

    private static func app(_ id: String, _ name: String, bundle: String?, focused: Bool = false,
                            windows: [(String, Bool)]) -> String {
        let list = windows.map { #"{"id":"\#($0.0)","title":"t","isFocused":\#($0.1)}"# }.joined(separator: ",")
        let bundleField = bundle.map { #""\#($0)""# } ?? "null"
        return #"{"id":"\#(id)","appName":"\#(name)","bundleId":\#(bundleField),"isFocused":\#(focused),"windowCount":\#(windows.count),"allWindows":[\#(list)]}"#
    }

    private static func monitor(_ workspaces: [(String, Bool, [String])], labels: Bool = false) -> OmniWMWorkspaceBarMonitor? {
        let items = workspaces.enumerated().map { index, workspace in
            #"{"id":"\#(workspace.0)","rawName":"\#(workspace.0)","displayName":"\#(workspace.0)","number":\#(index + 1),"isFocused":\#(workspace.1),"windows":[\#(workspace.2.joined(separator: ","))]}"#
        }.joined(separator: ",")
        let json = #"{"ok":true,"result":{"payload":{"interactionMonitorId":null,"monitors":[{"id":"display:1","name":"M","showLabels":\#(labels),"workspaces":[\#(items)]}]}}}"#
        return OmniWMWorkspaceSupport.decode(Data(json.utf8))?.monitors.first
    }

    private static func grouping(_ suite: TestSuite) {
        let workspace = monitor([("one", true, [
            app("a1", "Safari", bundle: "com.apple.Safari", windows: [("w1", false)]),
            app("b1", "Terminal", bundle: "com.apple.Terminal", windows: [("w2", false)]),
            app("a2", "Safari", bundle: "com.apple.Safari", focused: true, windows: [("w3", true)]),
            app("c1", "Tool", bundle: nil, windows: [])
        ])])?.workspaces.first
        let groups = workspace.map(OmniWMWorkspaceAppGroup.groups(in:)) ?? []
        suite.expect(groups.map(\.appName) == ["Safari", "Terminal", "Tool"],
                     "each app's windows share one icon, in the order OmniWM lists the apps")
        let safari = groups.first
        suite.expect(safari?.windows.map(\.id) == ["w1", "w3"] && safari?.isFocused == true,
                     "a grouped app keeps every window and its focus")
        suite.expect(safari?.target(cycling: true)?.id == "w1" && safari?.target(cycling: false)?.id == "w3",
                     "a repeat click walks to the next window; elsewhere it returns to the focused one")
        suite.expect(groups.last?.windows.map(\.id) == ["c1"] && groups[1].target(cycling: true)?.id == "w2",
                     "an app without a window list is still focusable, and one without focus starts at its first window")
        suite.expect(workspace?.isOccupied == true && monitor([("e", false, [])])?.workspaces.first?.isOccupied == false,
                     "a workspace reports whether it holds any window")
    }

    private static func sizing(_ suite: TestSuite, geometry: NotchGeometry) {
        let few = OmniWMWorkspaceLayout(monitor: monitor([("1", true, []), ("2", false, [])]), geometry: geometry)
        let many = OmniWMWorkspaceLayout(monitor: monitor((1...8).map { ("\($0)", $0 == 1, []) }), geometry: geometry)
        suite.expect(few.size.width < many.size.width,
                     "the strip fits its workspaces instead of reserving room it does not use")
        let pair = monitor([("1", true, []), ("2", false, [])])
        let small = OmniWMWorkspaceLayout(monitor: pair, geometry: geometry, scale: 0.7)
        let large = OmniWMWorkspaceLayout(monitor: pair, geometry: geometry, scale: 1.5)
        suite.expect(small.pillHeight < few.pillHeight && few.pillHeight < large.pillHeight
                     && small.iconSize < few.iconSize && few.iconSize < large.iconSize
                     && small.textSize < few.textSize && few.textSize < large.textSize,
                     "the size slider scales the pills, their icons and their text together")
        suite.expect(small.size.height == geometry.stripHeight && few.size.height == geometry.stripHeight
                     && large.size.height > geometry.stripHeight
                     && large.size.height - geometry.stripHeight == large.pillHeight - few.pillHeight,
                     "a smaller strip keeps the island's height and a larger one grows it by the extra")
        suite.expect(small.rowWidth(pair!.workspaces) < few.rowWidth(pair!.workspaces)
                     && few.rowWidth(pair!.workspaces) < large.rowWidth(pair!.workspaces),
                     "the pills' widths follow the size")
        let listed = OmniWMWorkspacePanelLayout(monitor: pair, geometry: geometry, scale: 1)
        let listedLarge = OmniWMWorkspacePanelLayout(monitor: pair, geometry: geometry, scale: 1.5)
        suite.expect(listedLarge.rowHeight > listed.rowHeight && listedLarge.iconSize > listed.iconSize
                     && listedLarge.size.height > listed.size.height,
                     "the list below the strip grows with the slider")
        suite.expect(OmniWMWorkspaceSupport.clamped(9) == 1.5 && OmniWMWorkspaceSupport.clamped(0.1) == 0.7
                     && OmniWMWorkspaceSupport.clamped(1) == 1,
                     "a saved size outside the slider's range is brought back into it")
        suite.expect((many.leading + many.trailing).map(\.id) == (1...8).map { "\($0)" }
                     && many.leading.count == 4,
                     "the pills split across the camera in order, evenly when they match in width")
        let lopsided = monitor([
            ("1", true, (1...3).map { app("a\($0)", "A\($0)", bundle: "a\($0)", windows: [("wa\($0)", false)]) }),
            ("2", false, (1...3).map { app("b\($0)", "B\($0)", bundle: "b\($0)", windows: [("wb\($0)", false)]) }),
            ("3", false, []), ("4", false, []), ("5", false, []), ("6", false, [])
        ])
        let balanced = OmniWMWorkspaceLayout(monitor: lopsided, geometry: geometry)
        let external = NotchGeometry(screen: geometry.screen, safeAreaTop: 0, cameraWidth: 0)
        let continuous = OmniWMWorkspaceLayout(monitor: lopsided, geometry: external)
        suite.expect(continuous.trailing.isEmpty && continuous.leading.count == 6,
                     "without a camera, uneven app counts stay in one centered workspace row")
        suite.expect(continuous.size.width == continuous.rowWidth(lopsided!.workspaces)
                     + continuous.endInset * 2,
                     "a camera-free bar has equal end insets without unused space from balancing wings")
        let halves = (balanced.rowWidth(balanced.leading), balanced.rowWidth(balanced.trailing))
        suite.expect(balanced.leading.count < 3 && abs(halves.0 - halves.1) < balanced.pillWidth(lopsided!.workspaces[0]),
                     "busy pills on one side are balanced by more empty ones on the other")
        suite.expect(balanced.leadingWidth == halves.0 + NotchLayout.compactEdgeGap
                     && balanced.trailingWidth == halves.1 + NotchLayout.compactEdgeGap,
                     "each wing is as wide as its own half of the pills, with no dead space for the other")
        suite.expect(balanced.size.width == balanced.leadingWidth + balanced.cameraGap + balanced.trailingWidth
                     + balanced.endInset * 2
                     && balanced.shift == (balanced.trailingWidth - balanced.leadingWidth) / 2,
                     "the strip reaches further toward its wider wing, keeping the camera's gap over the camera")
        suite.expect(continuous.shift == 0, "a camera-free bar stays centred")
        let crowded = monitor([("1", true, (1...6).map { app("x\($0)", "X\($0)", bundle: "x\($0)", windows: [("w\($0)", false)]) })])
        let three = monitor([("1", true, (1...3).map { app("x\($0)", "X\($0)", bundle: "x\($0)", windows: [("w\($0)", false)]) })])
        let crowdedPill = OmniWMWorkspaceLayout(monitor: crowded, geometry: geometry)
        let threePill = OmniWMWorkspaceLayout(monitor: three, geometry: geometry)
        suite.expect(crowdedPill.pillWidth(crowded!.workspaces[0]) - threePill.pillWidth(three!.workspaces[0]) < 24,
                     "a pill shows a few icons and counts the rest instead of growing with every app")
        let empty = monitor([("1", false, [])])!.workspaces[0]
        suite.expect(few.pillWidth(empty) == few.pillHeight, "a lone number keeps a square-cornered pill, not a sliver")
        let named = OmniWMWorkspaceLayout(monitor: monitor([("Development", true, []), ("Mail", false, [])], labels: true),
                                          geometry: geometry)
        suite.expect(named.size.width > few.size.width,
                     "named workspaces widen their pills to fit the name")
        suite.expect(OmniWMWorkspaceSupport.caption(.notInstalled) != OmniWMWorkspaceSupport.caption(.connected)
                     && OmniWMWorkspaceSupport.caption(.waiting).contains("IPC"),
                     "settings say whether OmniWM is missing, unreachable or connected")
    }
}

// Existing island contracts exercise the upstream presentation with the local bar disabled.
extension NotchDestinationContract.Service {
    var showsOmniWMWorkspaceBar: Bool { false }
    var showsOmniWMWorkspacePanel: Bool { false }
}
extension NotchHoverTests.Service {
    var showsOmniWMWorkspaceBar: Bool { false }
    var showsOmniWMWorkspacePanel: Bool { false }
}
extension NotchMirrorContract.Service {
    var showsOmniWMWorkspaceBar: Bool { false }
    var showsOmniWMWorkspacePanel: Bool { false }
}
extension NotchMusicVisibilityTests.Service {
    var showsOmniWMWorkspaceBar: Bool { false }
    var showsOmniWMWorkspacePanel: Bool { false }
}
extension NotchPresentationRefreshContract.Service {
    var showsOmniWMWorkspaceBar: Bool { false }
    var showsOmniWMWorkspacePanel: Bool { false }
}

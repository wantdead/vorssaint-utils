// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI

/// Every workspace as a pill with its apps, split across the camera so the
/// row reads as one bar the cutout interrupts.
struct OmniWMWorkspaceBarView: View {
    let geometry: NotchGeometry
    /// Off inside the panel, which reports the pointer for the whole surface.
    var reportsHover = true
    @ObservedObject private var service = OmniWMWorkspaceService.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selection
    @State private var hoveredID: String?

    private var monitor: OmniWMWorkspaceBarMonitor? { service.monitor(for: geometry.screen) }
    private var activeID: String? {
        if let pending = service.pendingWorkspaceID,
           monitor?.workspaces.contains(where: { $0.id == pending }) == true { return pending }
        return monitor?.workspaces.first(where: \.isFocused)?.id
    }
    /// The highlight is the only feedback for a click, so it lands quickly.
    private var motion: Animation? { reduceMotion ? nil : .spring(response: 0.26, dampingFraction: 0.86) }
    private var hoverMotion: Animation? { reduceMotion ? nil : .easeOut(duration: 0.12) }

    var body: some View {
        let layout = OmniWMWorkspaceLayout(monitor: monitor, geometry: geometry)
        HStack(spacing: 0) {
            if geometry.isNotched {
                row(layout.leading, width: layout.leadingWidth, layout: layout, alignment: .trailing)
                    .padding(.trailing, NotchLayout.compactEdgeGap)
                    .frame(width: layout.leadingWidth, alignment: .trailing)
                Color.clear.frame(width: layout.cameraGap)
                row(layout.trailing, width: layout.trailingWidth, layout: layout, alignment: .leading)
                    .padding(.leading, NotchLayout.compactEdgeGap)
                    .frame(width: layout.trailingWidth, alignment: .leading)
            } else {
                row(layout.leading, width: layout.leadingWidth, layout: layout, alignment: .center)
                    .frame(width: layout.leadingWidth)
            }
        }
        .padding(.horizontal, layout.endInset)
        .frame(width: layout.size.width, height: layout.size.height)
        .foregroundStyle(.white)
        .contentShape(Rectangle())
        .animation(motion, value: activeID)
        .onHover { if reportsHover { service.hover($0, screen: geometry.screen) } }
        .onDisappear {
            if reportsHover { service.hover(false, screen: geometry.screen) }
            hoveredID = nil
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("OmniWM workspaces")
        .accessibilityIdentifier("notch.omniwm.workspaces")
    }

    private func row(_ workspaces: [OmniWMWorkspaceBarWorkspace], width: CGFloat, layout: OmniWMWorkspaceLayout,
                     alignment: Alignment) -> some View {
        let room = max(0, width - (geometry.isNotched ? NotchLayout.compactEdgeGap : 0))
        return ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: OmniWMWorkspaceLayout.spacing) {
                    ForEach(workspaces) { workspace in
                        pill(workspace, layout: layout).id(workspace.id)
                    }
                }
                .frame(minWidth: room, alignment: alignment)
            }
            .scrollDisabled(layout.rowWidth(workspaces) <= room)
            .frame(height: layout.pillHeight)
            .onChange(of: activeID, initial: true) { _, id in
                if let id, workspaces.contains(where: { $0.id == id }) { proxy.scrollTo(id, anchor: .center) }
            }
        }
    }

    // MARK: Pills

    private func pill(_ workspace: OmniWMWorkspaceBarWorkspace, layout: OmniWMWorkspaceLayout) -> some View {
        let focused = workspace.id == activeID
        let hovered = hoveredID == workspace.id
        let groups = OmniWMWorkspaceAppGroup.groups(in: workspace)
        let shown = Array(groups.prefix(OmniWMWorkspaceLayout.iconCap))
        let overflow = groups.count - shown.count
        let shape = RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous)
        return HStack(spacing: OmniWMWorkspaceLayout.iconSpacing) {
            Text(OmniWMWorkspaceSupport.label(for: workspace, showLabels: layout.showLabels))
                .font(.system(size: layout.textSize, weight: focused ? .semibold : .medium))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(.white.opacity(focused ? 1 : workspace.isOccupied ? 0.55 : 0.3))
            ForEach(shown) { group in
                appButton(group, workspace: workspace, focused: focused, layout: layout)
            }
            if overflow > 0 {
                Text("+\(overflow)")
                    .font(.system(size: OmniWMWorkspaceLayout.overflowSize, weight: .semibold))
                    .monospacedDigit()
                    .fixedSize()
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .frame(width: layout.pillWidth(workspace), height: layout.pillHeight)
        // Beside a camera a fill on every pill outlines the housing, so the
        // strip stays plain, as the island's other strips are. Only the pointer
        // and the workspace on screen get a surface, drawn like its cards.
        .background {
            ZStack {
                shape.fill(.white.opacity(hovered && !focused ? 0.07 : 0))
                if focused {
                    shape.fill(.white.opacity(0.12))
                        .overlay(shape.strokeBorder(.white.opacity(0.16), lineWidth: 1))
                        .matchedGeometryEffect(id: "omniwm.focus", in: selection)
                }
            }
        }
        .contentShape(shape)
        // The pill switches workspace; its icons stay individually clickable.
        .onTapGesture { service.focus(workspace: workspace) }
        .onHover { inside in
            if inside { hoveredID = workspace.id } else if hoveredID == workspace.id { hoveredID = nil }
        }
        .animation(hoverMotion, value: hovered)
        .help(workspace.displayName)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(workspaceDescription(workspace, apps: groups.count))
        .accessibilityAddTraits(focused ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { service.focus(workspace: workspace) }
    }

    private func workspaceDescription(_ workspace: OmniWMWorkspaceBarWorkspace, apps: Int) -> String {
        let contents = apps == 0 ? "empty" : apps == 1 ? "1 app" : "\(apps) apps"
        return "Workspace \(workspace.displayName), \(contents)"
    }

    // MARK: Apps

    private func appButton(_ group: OmniWMWorkspaceAppGroup, workspace: OmniWMWorkspaceBarWorkspace,
                           focused: Bool, layout: OmniWMWorkspaceLayout) -> some View {
        Button {
            service.focus(group: group, in: workspace, cycling: focused)
        } label: {
            Group {
                if let icon = service.icon(for: group.bundleId) {
                    Image(nsImage: icon).resizable().interpolation(.high)
                } else {
                    Image(systemName: "app.dashed").resizable().scaledToFit().foregroundStyle(.white.opacity(0.6))
                }
            }
            .frame(width: layout.iconSize, height: layout.iconSize)
            // The window OmniWM would bring forward stands out from its neighbours.
            .opacity(group.isFocused && focused ? 1 : focused ? 0.85 : 0.7)
            .overlay(alignment: .bottomTrailing) {
                if group.windows.count > 1 { badge(group.windows.count).offset(x: 4, y: 3) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(NotchButtonStyle(cornerRadius: 4, highlights: false))
        .help(appDescription(group))
        .accessibilityLabel(appDescription(group))
        .accessibilityAddTraits(group.isFocused ? .isSelected : [])
    }

    private func badge(_ count: Int) -> some View {
        Text(count > 9 ? "9+" : "\(count)")
            .font(.system(size: 7, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 2)
            .frame(minWidth: 9, minHeight: 9)
            .background(Capsule().fill(Color(white: 0.34)))
            // A black rim parts the badge from the icon beneath it.
            .padding(1)
            .background(Capsule().fill(.black))
            .accessibilityHidden(true)
    }

    private func appDescription(_ group: OmniWMWorkspaceAppGroup) -> String {
        group.windows.count > 1 ? "\(group.appName), \(group.windows.count) windows" : group.appName
    }
}

/// The strip, and once Option lingers or the pointer rests on it, a short
/// list below it naming each workspace's apps.
struct OmniWMWorkspacePanelView: View {
    let geometry: NotchGeometry
    let expanded: Bool
    @ObservedObject private var service = OmniWMWorkspaceService.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var monitor: OmniWMWorkspaceBarMonitor? { service.monitor(for: geometry.screen) }
    private var activeID: String? {
        if let pending = service.pendingWorkspaceID,
           monitor?.workspaces.contains(where: { $0.id == pending }) == true { return pending }
        return monitor?.workspaces.first(where: \.isFocused)?.id
    }

    var body: some View {
        VStack(spacing: 0) {
            OmniWMWorkspaceBarView(geometry: geometry, reportsHover: false)
            if expanded {
                list(OmniWMWorkspacePanelLayout(monitor: monitor, geometry: geometry))
                    .padding(.top, OmniWMWorkspacePanelLayout.topGap)
                    // The lines settle in as the island drops open around them.
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: -6)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .contentShape(Rectangle())
        // The island reaches toward the wider wing; the strip and the list
        // below it move with it, keeping the camera's gap over the camera.
        .offset(x: OmniWMWorkspaceLayout(monitor: monitor, geometry: geometry).shift)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.88), value: expanded)
        .onHover { service.hover($0, screen: geometry.screen) }
        .onDisappear { service.hover(false, screen: geometry.screen) }
    }

    private func list(_ layout: OmniWMWorkspacePanelLayout) -> some View {
        HStack(alignment: .top, spacing: OmniWMWorkspacePanelLayout.columnSpacing) {
            ForEach(Array(layout.columns.enumerated()), id: \.offset) { _, column in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: OmniWMWorkspacePanelLayout.rowSpacing) {
                        ForEach(column) { workspace in
                            line(workspace, layout: layout)
                        }
                    }
                }
                .scrollDisabled(column.count <= OmniWMWorkspacePanelLayout.maximumLines)
                .frame(width: layout.columnWidth, height: layout.listHeight, alignment: .top)
            }
        }
        .padding(.horizontal, OmniWMWorkspacePanelLayout.horizontalInset)
        .frame(width: layout.size.width, alignment: .center)
    }

    private func line(_ workspace: OmniWMWorkspaceBarWorkspace, layout: OmniWMWorkspacePanelLayout) -> some View {
        let active = workspace.id == activeID
        let groups = OmniWMWorkspaceAppGroup.groups(in: workspace)
        let shown = Array(groups.prefix(OmniWMWorkspacePanelLayout.iconCap))
        let shape = RoundedRectangle(cornerRadius: OmniWMWorkspacePanelLayout.rowRadius, style: .continuous)
        let mark = workspace.number.map(String.init) ?? String(workspace.displayName.prefix(1))
        let names = groups.isEmpty ? "No windows" : OmniWMWorkspacePanelLayout.names(workspace)
        return HStack(spacing: 9) {
            Text(mark)
                .font(.system(size: 10, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(active ? .black : .white)
                .padding(.horizontal, mark.count > 1 ? 4 : 0)
                .frame(minWidth: 18, minHeight: 18)
                .background(Capsule().fill(active ? .white : .white.opacity(0.12)))
            if !shown.isEmpty {
                HStack(spacing: 4) {
                    ForEach(shown) { group in
                        icon(group, workspace: workspace, active: active)
                    }
                }
            }
            Text(names)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(.white.opacity(groups.isEmpty ? 0.4 : active ? 1 : 0.7))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(height: OmniWMWorkspacePanelLayout.rowHeight)
        .background(shape.fill(.white.opacity(active ? 0.1 : 0)))
        .contentShape(shape)
        // The line switches workspace; each icon focuses its app.
        .onTapGesture { service.focus(workspace: workspace) }
        .modifier(OmniWMHoverWash(shape: shape, enabled: !active))
        .help(workspace.displayName)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Workspace \(workspace.displayName), \(names)")
        .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { service.focus(workspace: workspace) }
    }

    private func icon(_ group: OmniWMWorkspaceAppGroup, workspace: OmniWMWorkspaceBarWorkspace,
                      active: Bool) -> some View {
        let size = OmniWMWorkspacePanelLayout.iconSize
        return Button {
            service.focus(group: group, in: workspace, cycling: active)
        } label: {
            Group {
                if let image = service.icon(for: group.bundleId) {
                    Image(nsImage: image).resizable().interpolation(.high)
                } else {
                    Image(systemName: "app.dashed").resizable().scaledToFit().foregroundStyle(.white.opacity(0.6))
                }
            }
            .frame(width: size, height: size)
            .contentShape(Rectangle())
        }
        .buttonStyle(NotchButtonStyle(cornerRadius: 4, highlights: false))
        .help(group.windows.count > 1 ? "\(group.appName), \(group.windows.count) windows" : group.appName)
        .accessibilityLabel(group.appName)
    }
}

/// The light wash a line takes under the pointer.
private struct OmniWMHoverWash<S: Shape>: ViewModifier {
    let shape: S
    let enabled: Bool
    @State private var hovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .background(shape.fill(.white.opacity(enabled && hovered ? 0.07 : 0)))
            .onHover { hovered = $0 }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: hovered)
    }
}

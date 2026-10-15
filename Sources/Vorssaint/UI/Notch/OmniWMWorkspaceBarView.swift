// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI

/// Every workspace as a pill with its apps, split across the camera so the
/// row reads as one bar the cutout interrupts.
struct OmniWMWorkspaceBarView: View {
    let geometry: NotchGeometry
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
            row(layout.leading, layout: layout, alignment: .trailing)
                .padding(.trailing, NotchLayout.compactEdgeGap)
                .frame(width: layout.wingWidth, alignment: .trailing)
            Color.clear.frame(width: layout.cameraGap)
            row(layout.trailing, layout: layout, alignment: .leading)
                .padding(.leading, NotchLayout.compactEdgeGap)
                .frame(width: layout.wingWidth, alignment: .leading)
        }
        .padding(.horizontal, layout.endInset)
        .frame(width: layout.size.width, height: layout.size.height)
        .foregroundStyle(.white)
        .contentShape(Rectangle())
        .animation(motion, value: activeID)
        .onHover { service.hover($0, screen: geometry.screen) }
        .onDisappear {
            service.hover(false, screen: geometry.screen)
            hoveredID = nil
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("OmniWM workspaces")
        .accessibilityIdentifier("notch.omniwm.workspaces")
    }

    private func row(_ workspaces: [OmniWMWorkspaceBarWorkspace], layout: OmniWMWorkspaceLayout,
                     alignment: Alignment) -> some View {
        let room = max(0, layout.wingWidth - NotchLayout.compactEdgeGap)
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
        let shape = Capsule(style: .continuous)
        return HStack(spacing: OmniWMWorkspaceLayout.iconSpacing) {
            Text(OmniWMWorkspaceSupport.label(for: workspace, showLabels: layout.showLabels))
                .font(.system(size: layout.textSize, weight: focused ? .semibold : .medium))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(.white.opacity(focused ? 1 : workspace.isOccupied ? 0.75 : 0.4))
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
        .background {
            ZStack {
                // Empty workspaces recede, so the occupied ones read first.
                shape.fill(.white.opacity(hovered ? 0.14 : workspace.isOccupied ? 0.08 : 0.04))
                if focused {
                    shape.fill(.white.opacity(0.22))
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

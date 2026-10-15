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
        .onHover { if reportsHover { service.hover($0, screen: geometry.screen) } }
        .onDisappear {
            if reportsHover { service.hover(false, screen: geometry.screen) }
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

/// The strip, and once Option lingers or the pointer rests on it, a row of
/// workspace cards dropped below it, drawn like the open island's cards.
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
                cards(OmniWMWorkspacePanelLayout(monitor: monitor, geometry: geometry))
                    .padding(.top, OmniWMWorkspacePanelLayout.topGap)
                    // The cards settle in as the island drops open around them.
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: -10)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.88), value: expanded)
        .onHover { service.hover($0, screen: geometry.screen) }
        .onDisappear { service.hover(false, screen: geometry.screen) }
    }

    private func cards(_ layout: OmniWMWorkspacePanelLayout) -> some View {
        let count = CGFloat(layout.cards.count)
        let content = count * OmniWMWorkspacePanelLayout.cardWidth
            + max(0, count - 1) * OmniWMWorkspacePanelLayout.cardSpacing + NotchLayout.horizontalInset * 2
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: OmniWMWorkspacePanelLayout.cardSpacing) {
                ForEach(layout.cards) { workspace in
                    card(workspace, layout: layout)
                }
            }
            .padding(.horizontal, NotchLayout.horizontalInset)
            .frame(minWidth: layout.size.width, alignment: .center)
        }
        .scrollDisabled(content <= layout.size.width)
        .frame(height: layout.cardHeight)
    }

    private func card(_ workspace: OmniWMWorkspaceBarWorkspace, layout: OmniWMWorkspacePanelLayout) -> some View {
        let active = workspace.id == activeID
        let rows = OmniWMWorkspaceWindowRow.rows(in: workspace)
        let shown = Array(rows.prefix(OmniWMWorkspacePanelLayout.maximumRows))
        let shape = RoundedRectangle(cornerRadius: OmniWMWorkspacePanelLayout.cardRadius, style: .continuous)
        return VStack(alignment: .leading, spacing: 0) {
            header(workspace, windows: rows.count, active: active, showLabels: layout.strip.showLabels)
                .padding(.bottom, 2)
            if rows.isEmpty {
                Text("No windows")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            ForEach(shown) { row in
                windowRow(row, workspace: workspace, active: active)
            }
            if rows.count > shown.count {
                Text("+\(rows.count - shown.count) more")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(height: OmniWMWorkspacePanelLayout.overflowHeight)
            }
        }
        .padding(OmniWMWorkspacePanelLayout.cardPadding)
        .frame(width: OmniWMWorkspacePanelLayout.cardWidth, height: layout.cardHeight, alignment: .topLeading)
        .background(shape.fill(.white.opacity(active ? 0.11 : 0.06)))
        .overlay(shape.strokeBorder(.white.opacity(active ? 0.2 : 0.07), lineWidth: 1))
        .contentShape(shape)
        // The card switches workspace; each window row focuses its window.
        .onTapGesture { service.focus(workspace: workspace) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Workspace \(workspace.displayName)")
        .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { service.focus(workspace: workspace) }
    }

    private func header(_ workspace: OmniWMWorkspaceBarWorkspace, windows: Int, active: Bool,
                        showLabels: Bool) -> some View {
        let mark = workspace.number.map(String.init) ?? String(workspace.displayName.prefix(1))
        let name = workspace.number == nil || (showLabels && workspace.displayName != mark)
            ? workspace.displayName : nil
        return HStack(spacing: 7) {
            Text(mark)
                .font(.system(size: 11, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(active ? .black : .white)
                .padding(.horizontal, mark.count > 1 ? 5 : 0)
                .frame(minWidth: 20, minHeight: 20)
                .background(Capsule().fill(active ? .white : .white.opacity(0.12)))
            if let name {
                Text(name).font(.system(size: 12.5, weight: .semibold)).lineLimit(1)
            }
            Spacer(minLength: 4)
            Text(windows == 1 ? "1 window" : "\(windows) windows")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
                .opacity(windows == 0 ? 0 : 1)
        }
        .frame(height: OmniWMWorkspacePanelLayout.headerHeight)
    }

    private func windowRow(_ row: OmniWMWorkspaceWindowRow, workspace: OmniWMWorkspaceBarWorkspace,
                           active: Bool) -> some View {
        Button { service.focus(window: row, in: workspace) } label: {
            HStack(spacing: 8) {
                Group {
                    if let icon = service.icon(for: row.bundleId) {
                        Image(nsImage: icon).resizable().interpolation(.high)
                    } else {
                        Image(systemName: "app.dashed").resizable().scaledToFit().foregroundStyle(.white.opacity(0.6))
                    }
                }
                .frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 0) {
                    Text(row.title ?? row.appName)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    if row.title != nil {
                        Text(row.appName)
                            .font(.system(size: 10.5))
                            .foregroundStyle(.white.opacity(0.45))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                if row.isFocused {
                    // The window this workspace brings forward.
                    Circle().fill(.white.opacity(active ? 0.9 : 0.4)).frame(width: 5, height: 5)
                }
            }
            .padding(.horizontal, 6)
            .frame(height: OmniWMWorkspacePanelLayout.rowHeight)
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(NotchButtonStyle(cornerRadius: 9, lifts: false))
        .padding(.horizontal, -6)
        .help(row.title.map { "\($0) — \(row.appName)" } ?? row.appName)
        .accessibilityLabel(row.title.map { "\(row.appName), \($0)" } ?? row.appName)
        .accessibilityAddTraits(row.isFocused ? .isSelected : [])
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import SwiftUI

struct OmniWMWorkspaceBarView: View {
    let geometry: NotchGeometry
    @ObservedObject private var service = OmniWMWorkspaceService.shared

    private var monitor: OmniWMWorkspaceBarMonitor? { service.monitor(for: geometry.screen) }
    private var layout: OmniWMWorkspaceLayout { OmniWMWorkspaceLayout(monitor: monitor, geometry: geometry) }
    private var activeWorkspace: OmniWMWorkspaceBarWorkspace? {
        if let pending = service.pendingWorkspaceID,
           let workspace = monitor?.workspaces.first(where: { $0.id == pending }) { return workspace }
        return monitor?.workspaces.first(where: \.isFocused)
    }
    private var textSize: CGFloat { min(12, layout.controlSide - 6) }
    private var iconSize: CGFloat { min(16, layout.controlSide - 8) }

    var body: some View {
        HStack(spacing: 0) {
            workspaceSelectors
                .padding(.trailing, NotchLayout.compactEdgeGap)
                .frame(width: layout.wingWidth)
            Color.clear.frame(width: layout.cameraGap)
            applicationSelectors
                .padding(.leading, NotchLayout.compactEdgeGap)
                .frame(width: layout.wingWidth)
        }
        .padding(.horizontal, layout.endInset)
        .frame(width: layout.size.width, height: layout.size.height)
        .foregroundStyle(.white)
        .contentShape(Rectangle())
        .onHover { service.hover($0, screen: geometry.screen) }
        .onDisappear { service.hover(false, screen: geometry.screen) }
        .accessibilityIdentifier("notch.omniwm.workspaces")
    }

    private var workspaceSelectors: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: OmniWMWorkspaceLayout.spacing) {
                    ForEach(monitor?.workspaces ?? []) { workspace in
                        workspaceButton(workspace).id(workspace.id)
                    }
                }
                .frame(minWidth: max(0, layout.wingWidth - NotchLayout.compactEdgeGap), alignment: .leading)
            }
            .frame(height: layout.controlSide)
            .onAppear { if let id = activeWorkspace?.id { proxy.scrollTo(id, anchor: .center) } }
            .onChange(of: activeWorkspace?.id) { _, id in
                if let id { proxy.scrollTo(id, anchor: .center) }
            }
        }
    }

    @ViewBuilder private var applicationSelectors: some View {
        if let workspace = activeWorkspace, !workspace.apps.isEmpty {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: OmniWMWorkspaceLayout.spacing) {
                        ForEach(workspace.apps) { app in
                            appButton(app, workspace: workspace).id(app.id)
                        }
                    }
                    .frame(minWidth: max(0, layout.wingWidth - NotchLayout.compactEdgeGap), alignment: .trailing)
                }
                .frame(height: layout.controlSide)
                .onChange(of: workspace.apps.first(where: \.isFocused)?.id, initial: true) { _, id in
                    if let id { proxy.scrollTo(id, anchor: .center) }
                }
            }
        } else {
            HStack(spacing: NotchCapsuleLayout.spacing) {
                Image(systemName: "rectangle.3.group")
                    .font(.system(size: NotchCapsuleLayout.symbolSize, weight: .medium))
                Text(service.status.isEmpty ? "No windows" : service.status)
                    .font(.system(size: textSize, weight: .medium)).lineLimit(1)
            }
            .foregroundStyle(.white.opacity(0.55))
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func workspaceButton(_ workspace: OmniWMWorkspaceBarWorkspace) -> some View {
        let selected = activeWorkspace?.id == workspace.id
        let name = monitor?.showLabels == true ? workspace.displayName
            : workspace.number.map(String.init) ?? workspace.displayName
        return Button { service.focus(workspace: workspace) } label: {
            Text(name)
                .font(.system(size: textSize, weight: .medium)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.75)
                .foregroundStyle(selected ? .white : .white.opacity(0.55))
                .frame(minWidth: layout.controlSide, minHeight: layout.controlSide)
                .padding(.horizontal, name.count > 2 ? 6 : 0)
                .background(.white.opacity(selected ? 0.12 : 0),
                            in: RoundedRectangle(cornerRadius: OmniWMWorkspaceLayout.cornerRadius, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: OmniWMWorkspaceLayout.cornerRadius, style: .continuous))
        }
        .buttonStyle(NotchButtonStyle(cornerRadius: OmniWMWorkspaceLayout.cornerRadius, lifts: false))
        .help(workspace.displayName)
        .accessibilityLabel("Switch to workspace \(workspace.displayName)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func appButton(_ app: OmniWMWorkspaceBarApp, workspace: OmniWMWorkspaceBarWorkspace) -> some View {
        Button { service.focus(app: app, workspaceID: workspace.id) } label: {
            Group {
                if let icon = service.icon(for: app.bundleId) {
                    Image(nsImage: icon).resizable().interpolation(.high)
                } else {
                    Image(systemName: "app.fill").resizable().padding(2)
                }
            }
            .frame(width: iconSize, height: iconSize)
            .frame(width: layout.controlSide, height: layout.controlSide)
            .background(.white.opacity(app.isFocused ? 0.12 : 0),
                        in: RoundedRectangle(cornerRadius: OmniWMWorkspaceLayout.cornerRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: OmniWMWorkspaceLayout.cornerRadius, style: .continuous))
        }
        .buttonStyle(NotchButtonStyle(cornerRadius: OmniWMWorkspaceLayout.cornerRadius, lifts: false))
        .help(app.appName)
        .accessibilityLabel("Focus \(app.appName), workspace \(workspace.displayName)")
        .accessibilityAddTraits(app.isFocused ? .isSelected : [])
    }
}

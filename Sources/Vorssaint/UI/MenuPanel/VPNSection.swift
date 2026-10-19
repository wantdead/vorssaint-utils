// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The "VPN" card: status of OpenVPN Connect, a profile picker and one
/// connect/disconnect button. The PIN is entered in OpenVPN Connect itself.
struct VPNSection: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = OpenVPNService.shared
    @State private var selectedID: String?
    var collapsible = true

    private var strings: OpenVPNFeatureStrings { FeatureStrings.openVPN(l10n.language) }

    var body: some View {
        PanelSection(.vpn, title: strings.pageTitle, collapsible: collapsible) {
            VStack(alignment: .leading, spacing: 10) {
                statusRow
                if service.status != .unavailable(.appMissing) {
                    controls
                }
            }
            .panelCard()
            .onAppear { service.panelDidAppear() }
            .onDisappear { service.panelDidDisappear() }
        }
    }

    private var statusRow: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var controls: some View {
        if service.profiles.isEmpty {
            Text(strings.noProfiles)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
        } else {
            HStack(spacing: 8) {
                Text(strings.profile)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                Picker(strings.profile, selection: profileSelection) {
                    ForEach(service.profiles) { profile in
                        Text(profile.name).tag(Optional(profile.id))
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                Spacer(minLength: 0)
                actionButton
            }
        }
        if service.status == .connecting {
            HStack(spacing: 8) {
                Text(strings.pinHint)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Button(strings.openApp) { service.raiseApp() }
                    .controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if case .connected = service.status {
            Button(strings.disconnect) { service.disconnect() }
                .controlSize(.small)
        } else {
            Button(strings.connect) {
                if let id = profileSelection.wrappedValue { service.connect(profileID: id) }
            }
            .controlSize(.small)
            .disabled(service.status == .connecting)
        }
    }

    private var profileSelection: Binding<String?> {
        Binding(get: { selectedID ?? service.profiles.first?.id },
                set: { selectedID = $0 })
    }

    private var statusText: String {
        switch service.status {
        case let .connected(name):
            return name.map { "\(strings.statusConnected) · \($0)" } ?? strings.statusConnected
        case .connecting:
            return strings.statusConnecting
        case .disconnected:
            return strings.statusDisconnected
        case .unavailable(.appMissing):
            return strings.appMissing
        case .unavailable(.logUnreadable), .unavailable(.commandFailed):
            return strings.cannotControl
        }
    }

    private var statusColor: Color {
        switch service.status {
        case .connected: return .green
        case .connecting: return .orange
        case .disconnected: return .secondary
        case .unavailable: return .red
        }
    }
}

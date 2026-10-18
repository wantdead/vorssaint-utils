// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// OmniWM's own page: whether its workspaces show in the Dynamic Island, how
/// the connection stands, and how big the strip and its list are drawn.
struct OmniWMSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var omniWM = OmniWMWorkspaceService.shared
    @AppStorage(DefaultsKey.notchEnabled) private var islandEnabled = false
    @AppStorage(OmniWMWorkspaceSupport.preferenceKey) private var enabled = true
    @AppStorage(OmniWMWorkspaceSupport.scaleKey) private var scale = 1.0

    private var text: OmniWMStrings { FeatureStrings.omniWM(l10n.language) }
    private var islandOn: Bool { features.isAvailable(.notch) && islandEnabled }
    private var range: ClosedRange<Double> { OmniWMWorkspaceSupport.scaleRange }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if !islandOn { islandNote }
                SettingsCard {
                    SettingsRow(symbol: AppFeature.notchOmniWM.symbolName, title: text.title,
                                caption: OmniWMWorkspaceSupport.caption(enabled ? omniWM.connection : .off)) {
                        Toggle(text.title, isOn: $enabled).labelsHidden().toggleStyle(.switch)
                    }
                }
                sizeCard
            }
            .padding(22)
        }
        .onChange(of: enabled) { _, _ in NotchService.shared.syncWithPreferences() }
        .onChange(of: scale) { _, _ in omniWM.scaleChanged() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(text.title).font(.title2.bold())
            Text(text.hint).font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var islandNote: some View {
        HStack(spacing: 12) {
            Image(systemName: AppFeature.notch.symbolName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 26, height: 26)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            Text(text.needsIsland)
            Spacer(minLength: 12)
            Button(FeatureStrings.notch(l10n.language).title) {
                SettingsRouter.shared.request(AppFeature.notch.settingsDestination)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var sizeCard: some View {
        let bounded = Binding(get: { OmniWMWorkspaceSupport.clamped(scale) },
                              set: { scale = Double($0) })
        let percent = Int((Double(bounded.wrappedValue) * 100).rounded())
        let formatted = Double(percent / 100).formatted(.percent.locale(Locale(identifier: l10n.language.rawValue)))
        return SettingsCard(title: text.size) {
            HStack(spacing: 12) {
                Image(systemName: "textformat.size.smaller").foregroundStyle(.secondary).accessibilityHidden(true)
                Slider(value: $scale, in: range, step: 0.05) { Text(text.size) }
                    .labelsHidden()
                    .accessibilityValue(formatted)
                Image(systemName: "textformat.size.larger").foregroundStyle(.secondary).accessibilityHidden(true)
                Text("\(percent)%").monospacedDigit().foregroundStyle(.secondary).frame(width: 44, alignment: .trailing)
                Button(text.defaultSize) { scale = 1 }.disabled(percent == 100)
            }
            Text(text.sizeHint).font(.caption).foregroundStyle(.secondary)
        }
    }
}

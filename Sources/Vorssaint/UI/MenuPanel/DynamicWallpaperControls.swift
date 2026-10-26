// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct DynamicWallpaperControls: View {
    @ObservedObject var service: WallpaperService
    @ObservedObject var dynamic: DynamicWallpaperService
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.notchPresentation) private var inNotch
    @State private var isExpanded = false

    private var text: DynamicWallpaperStrings { .localized(l10n.language) }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                Picker(text.title, selection: Binding(get: { dynamic.mode }, set: { dynamic.setMode($0) })) {
                    Text(text.off).tag(DynamicWallpaperSupport.Mode.off)
                    Text(text.appearance).tag(DynamicWallpaperSupport.Mode.appearance)
                    Text(text.schedule).tag(DynamicWallpaperSupport.Mode.schedule)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)

                if dynamic.mode != .off {
                    HStack(alignment: .top, spacing: 8) {
                        imageChoice(for: .day)
                        imageChoice(for: .night)
                    }
                    if dynamic.mode == .schedule {
                        HStack(spacing: 8) {
                            timePicker(for: .day)
                            timePicker(for: .night)
                        }
                    }
                    Text(dynamic.mode == .appearance ? text.appearanceHint : text.scheduleHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if dynamic.imageUnavailable {
                        status(text.unavailable)
                    } else if !dynamic.hasPair {
                        status(text.missingImages)
                    } else if dynamic.mode == .schedule, !dynamic.schedule.isValid {
                        status(text.invalidTimes)
                    }
                }
            }
            .padding(.top, 6)
        } label: {
            HStack {
                Label(text.title, systemImage: "sun.max.circle")
                    .font(.caption)
                Spacer(minLength: 4)
                if dynamic.hasPair, let period = dynamic.currentPeriod {
                    Image(systemName: period.symbol)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(period == .day ? text.day : text.night)
                }
            }
        }
        .onAppear { isExpanded = dynamic.mode != .off }
    }

    private func imageChoice(for period: DynamicWallpaperSupport.Period) -> some View {
        let title = period == .day ? text.day : text.night
        let url = dynamic.images[period]
        return VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: period.symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let url {
                WallpaperThumbButton(
                    entry: WallpaperSupport.Entry(id: url.path, imageURL: url, previewURL: url,
                        title: "\(title): \(WallpaperSupport.title(for: url))", source: .own),
                    isApplied: dynamic.currentPeriod == period,
                    thumbEpoch: service.thumbEpoch,
                    height: 64
                ) {
                    service.chooseDynamicImage(for: period, inNotch: inNotch)
                }
                Text(WallpaperSupport.title(for: url))
                    .font(.caption2)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.secondary)
            } else {
                Button {
                    service.chooseDynamicImage(for: period, inNotch: inNotch)
                } label: {
                    Image(systemName: "plus")
                        .frame(maxWidth: .infinity)
                        .frame(height: 64)
                        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help(text.chooseImage)
                .accessibilityLabel("\(title): \(text.chooseImage)")
                Text(text.chooseImage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func timePicker(for period: DynamicWallpaperSupport.Period) -> some View {
        DatePicker(period == .day ? text.day : text.night, selection: Binding(
            get: {
                let minute = dynamic.schedule.start(for: period)
                return Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60,
                                             second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                dynamic.setStart((components.hour ?? 0) * 60 + (components.minute ?? 0), for: period)
            }
        ), displayedComponents: .hourAndMinute)
        .labelsHidden()
        .datePickerStyle(.field)
        .controlSize(.small)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func status(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
    }
}

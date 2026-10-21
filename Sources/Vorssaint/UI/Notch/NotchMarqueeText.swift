// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// One line that fits or scrolls. The plain text sets the layout, so the row
/// never grows; a title wider than its room is drawn over it as a looping
/// strip. Reduce Motion keeps the truncated text.
struct NotchMarqueeText: View {
    let text: String
    let font: Font
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var container: CGFloat = 0
    @State private var natural: CGFloat = 0
    @State private var started = Date()

    private var travel: CGFloat? {
        reduceMotion ? nil : NotchMarquee.travel(text: natural, container: container)
    }

    var body: some View {
        Text(text).font(font).lineLimit(1).truncationMode(.tail)
            .contentTransition(.opacity)
            .opacity(travel == nil ? 1 : 0)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { container = $0 }
            .background {
                Text(text).font(font).fixedSize().hidden()
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { natural = $0 }
            }
            .overlay(alignment: .leading) {
                if let travel { strip(travel) }
            }
            .onChange(of: text) { started = Date() }
    }

    private func strip(_ travel: CGFloat) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
            HStack(spacing: NotchMarquee.gap) {
                Text(text).font(font).fixedSize()
                Text(text).font(font).fixedSize()
            }
            .offset(x: NotchMarquee.offset(travel: travel, elapsed: context.date.timeIntervalSince(started)))
        }
        .frame(width: container, alignment: .leading)
        .clipped()
        .mask {
            // A soft edge on the side the words leave from and arrive at.
            LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.04),
                                   .init(color: .black, location: 0.94), .init(color: .clear, location: 1)],
                           startPoint: .leading, endPoint: .trailing)
        }
        .accessibilityHidden(true)
    }
}

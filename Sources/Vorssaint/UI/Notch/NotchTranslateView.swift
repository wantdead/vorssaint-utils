// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Translate inside the island: text goes in above, the translation shows
/// below. The direction follows the text; the swap button flips it until the
/// text changes again.
struct NotchTranslateView: View {
    @ObservedObject private var translator = TranslateService.shared
    @ObservedObject private var l10n = L10n.shared
    @State private var input = ""
    @State private var direction: TranslateDirection?
    @State private var copied = false
    @State private var editor = EditorHandle()
    private var text: TranslateFeatureStrings { FeatureStrings.translate(l10n.language) }
    private static let editorInset = NSSize(width: 6, height: 6)

    /// Holds the editor's text view so the caret can land in it on open. Weak,
    /// since the view belongs to the editor.
    private final class EditorHandle {
        weak var view: NSTextView?
    }

    private var effectiveDirection: TranslateDirection? {
        direction ?? TranslateDirection.detect(input)
    }

    private var resultText: String? {
        if case .result(let translation) = translator.state { return translation }
        return nil
    }

    var body: some View {
        VStack(spacing: 6) {
            toolbar
            ZStack(alignment: .topLeading) {
                PlainTextEditor(text: $input, fontSize: PlainTextEditor.defaultFontSize,
                                textColor: .white,
                                textContainerInset: Self.editorInset, onCreate: { view in
                    view.insertionPointColor = .white
                    editor.view = view
                    DispatchQueue.main.async { focusEditor() }
                })
                if input.isEmpty {
                    Text(text.placeholder)
                        .font(.system(size: PlainTextEditor.defaultFontSize))
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.leading, Self.editorInset.width + PlainTextEditor.lineFragmentPadding)
                        .padding(.top, Self.editorInset.height)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .modifier(NotchControlSurface(cornerRadius: 12, interactive: false))
            resultArea
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .modifier(NotchControlSurface(cornerRadius: 12, interactive: false))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .translateHost()
        .onChange(of: input) { _, _ in direction = nil }
        .task(id: input) {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            translator.translate(input)
        }
        .task(id: copied) {
            guard copied else { return }
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            copied = false
        }
        .onDisappear { translator.translate("") }
    }

    private var toolbar: some View {
        HStack(spacing: 6) {
            Text(directionLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .accessibilityHidden(true)
            Spacer(minLength: 0)
            NotchIconButton(symbol: "arrow.left.arrow.right", title: text.swapHint) { swap() }
                .disabled(effectiveDirection == nil)
            NotchIconButton(symbol: copied ? "checkmark" : "doc.on.doc", title: text.copyHint) { copy() }
                .disabled(resultText == nil)
        }
    }

    @ViewBuilder private var resultArea: some View {
        switch translator.state {
        case .idle:
            Color.clear
        case .translating:
            ProgressView().controlSize(.small).padding(10)
        case .result(let translation):
            ScrollView {
                Text(translation)
                    .font(.system(size: PlainTextEditor.defaultFontSize))
                    .foregroundStyle(.white)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
        case .needsLanguagePack:
            notice(text.downloadNeeded)
        case .unavailable:
            notice(text.unavailable)
        case .failed:
            notice(text.failed)
        }
    }

    private func notice(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .font(.system(size: 10.5))
            .foregroundStyle(.white.opacity(0.6))
            .fixedSize(horizontal: false, vertical: true)
            .padding(10)
    }

    private var directionLabel: String {
        switch effectiveDirection {
        case .russianToEnglish: return "RU → EN"
        case .englishToRussian: return "EN → RU"
        case nil: return "RU ↔ EN"
        }
    }

    private func swap() {
        guard let current = effectiveDirection else { return }
        direction = current.swapped
        translator.translate(input, direction: direction)
    }

    private func copy() {
        guard let resultText else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.declareVorssaintSource()
        NSPasteboard.general.setString(resultText, forType: .string)
        copied = true
    }

    private func focusEditor() {
        guard let view = editor.view, let window = view.window, window.isKeyWindow else { return }
        window.makeFirstResponder(view)
    }
}

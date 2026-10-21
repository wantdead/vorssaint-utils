// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

enum NotchSliderEditingTests {
    static func run(_ suite: TestSuite) {
        nativeRefresh(suite)
        nativeColors(suite)
        var editing = NotchSliderEditing()
        var position = 32.0
        var callbacks: [Bool] = []
        var commits: [Double] = []
        let changed: (Bool) -> Void = { isEditing in
            callbacks.append(isEditing)
            if !isEditing { commits.append(position) }
        }
        editing.valueChanged({ position = 75 }, onEditingChanged: changed)
        suite.expect(position == 75 && commits == [75] && callbacks == [true, false],
               "an accessibility value action commits the new playback position without requiring mouse tracking")
        editing.valueChanged({ position = 76 }, onEditingChanged: changed)
        editing.valueChanged({ position = 77 }, onEditingChanged: changed)
        suite.expect(commits == [75, 76, 77] && callbacks == [true, false, true, false, true, false],
               "consecutive keyboard changes each complete their own edit after updating the bound value")

        callbacks = []; commits = []
        editing.trackingChanged(true, onEditingChanged: changed)
        for value in 0...100 {
            editing.valueChanged({ position = Double(value) }, onEditingChanged: changed)
        }
        suite.expect(position == 100 && callbacks == [true] && commits.isEmpty,
               "continuous mouse movement updates the thumb without submitting a seek for every sample")
        editing.trackingChanged(false, onEditingChanged: changed)
        suite.expect(callbacks == [true, false] && commits == [100],
               "finishing a drag commits its final bound position exactly once")
        editing.trackingChanged(false, onEditingChanged: changed)
        suite.expect(commits == [100], "a repeated native tracking-end callback cannot submit the drag again")
        editing.valueChanged({ position = 110 }, onEditingChanged: changed)
        suite.expect(commits == [100, 110] && callbacks.suffix(2) == [true, false],
               "keyboard or accessibility input after a drag still receives a complete edit cycle")

        var levels: [Double] = []
        editing.valueChanged({ levels.append(0.25) }, onEditingChanged: nil)
        editing.trackingChanged(true, onEditingChanged: nil)
        editing.valueChanged({ levels.append(0.5) }, onEditingChanged: nil)
        editing.trackingChanged(false, onEditingChanged: nil)
        editing.valueChanged({ levels.append(0.75) }, onEditingChanged: nil)
        suite.expect(levels == [0.25, 0.5, 0.75],
               "volume and brightness controls without an editing callback retain exactly one value write per action")
    }

    private static func nativeColors(_ suite: TestSuite) {
        typealias Native = NotchNativeSliderContract
        var model = Native.Model()
        model.value = 0.5
        model.trackThickness = 5
        model.preservesColorWhenDisabled = true
        let coordinator = Native.Model.Coordinator(model)
        var context = Native.Context(coordinator: coordinator)
        let slider = model.makeNSView(context: context)
        slider.frame = NSRect(x: 0, y: 0, width: 100, height: 22)
        let cell = slider.cell as! NotchLevelCell
        cell.controlView = slider
        func alpha() -> CGFloat {
            let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 100, pixelsHigh: 22,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
            cell.drawBar(inside: slider.bounds, flipped: false)
            NSGraphicsContext.restoreGraphicsState()
            return bitmap.colorAt(x: 20, y: 11)!.alphaComponent
        }
        model.updateNSView(slider, context: context)
        let enabled = alpha()
        context.environment.isEnabled = false
        model.updateNSView(slider, context: context)
        suite.expect(enabled > 0.8, "the native timeline renders an opaque filled segment in the pixel regression")
        suite.expect(abs(alpha() - enabled) < 0.01,
            "waiting for a seek command cannot flash the timeline from full color to a dimmed fill")
        model.preservesColorWhenDisabled = false
        model.updateNSView(slider, context: context)
        suite.expect(alpha() < enabled - 0.3,
            "ordinary disabled level controls retain their unavailable appearance")
    }

    private static func nativeRefresh(_ suite: TestSuite) {
        typealias Native = NotchNativeSliderContract
        var model = Native.Model()
        model.value = 0.2
        let coordinator = Native.Model.Coordinator(model)
        var committed: [Double] = []
        model.onEditingChanged = { [weak coordinator] editing in
            if !editing, let coordinator { committed.append(coordinator.parent.value) }
        }
        let context = Native.Context(coordinator: coordinator)
        let slider = model.makeNSView(context: context)
        model.updateNSView(slider, context: context)
        let tracking = (slider.cell as! NotchLevelCell).trackingChanged!
        tracking(true)
        slider.doubleValue = 0.8
        model.value = 0.1
        model.updateNSView(slider, context: context)
        suite.expect(slider.doubleValue == 0.8,
            "a playback refresh during native dragging cannot overwrite the thumb with the old song position")
        slider.doubleValue = 0.7
        tracking(false)
        suite.expect(coordinator.parent.value == 0.7 && committed == [0.7],
            "ending native tracking commits the final mouse position before the edit callback runs")
        model.value = 0.72
        model.updateNSView(slider, context: context)
        suite.expect(slider.doubleValue == 0.72,
            "playback resumes updating the native thumb after tracking ends")
    }
}

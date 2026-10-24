import AppKit
import SwiftUI
import Testing
@testable import Bonsplit

/// The selected tab is tinted, bold and underlined only when the host opts in
/// through `Appearance.selectedTabStyle`; the paint also encodes whether the
/// pane has focus and whether its window is key, so the tab bar never
/// desaturates it.
@Suite("Selected tab style")
@MainActor
struct SelectedTabStyleTests {
    /// The ShellX palette: accent tint in the focused pane, lavender grey elsewhere.
    private let style = SelectedTabStyle(
        fillHex: "#60A5FA29",
        inactiveWindowFillHex: "#60A5FA1F",
        unfocusedPaneFillHex: "#E6E2F212",
        titleHex: "#F1F5FF",
        unfocusedPaneTitleHex: "#CDC7E0",
        indicatorHex: "#60A5FA",
        unfocusedPaneIndicatorHex: "#5B5478"
    )

    // MARK: - Paint

    @Test("The focused pane in the key window paints the style's accent fill, title and indicator")
    func focusedPaneUsesStyleFill() {
        let paint = SelectedTabPaint(style: style, isPaneFocused: true, isWindowKey: true)

        #expect(isClose(paint.fill, toHex: 0x60A5FA, alpha: 0.16), "fill was \(describe(paint.fill))")
        #expect(isClose(paint.title, toHex: 0xF1F5FF), "title was \(describe(paint.title))")
        #expect(isClose(paint.indicator, toHex: 0x60A5FA), "indicator was \(describe(paint.indicator))")
        #expect(paint.titleWeight == .semibold)
    }

    @Test("A window that is not key softens only the fill")
    func inactiveWindowUsesInactiveFill() {
        let paint = SelectedTabPaint(style: style, isPaneFocused: true, isWindowKey: false)

        #expect(isClose(paint.fill, toHex: 0x60A5FA, alpha: 0.12), "fill was \(describe(paint.fill))")
        #expect(isClose(paint.title, toHex: 0xF1F5FF), "title was \(describe(paint.title))")
        #expect(isClose(paint.indicator, toHex: 0x60A5FA), "indicator was \(describe(paint.indicator))")
        #expect(paint.titleWeight == .semibold)
    }

    @Test("A window dims only when it is neither key nor main in the active app, like the session row")
    func windowDimsLikeTheSessionRow() {
        #expect(TabBarWindowKeyProbe.paintsAsKey(.key))
        #expect(TabBarWindowKeyProbe.paintsAsKey(.active), "main but not key (a sheet or panel is key) stays bright")
        #expect(!TabBarWindowKeyProbe.paintsAsKey(.inactive))
    }

    @Test("An unfocused pane gets the neutral paint whether or not its window is key")
    func unfocusedPaneUsesNeutralPaint() {
        for isWindowKey in [true, false] {
            let paint = SelectedTabPaint(style: style, isPaneFocused: false, isWindowKey: isWindowKey)

            #expect(isClose(paint.fill, toHex: 0xE6E2F2, alpha: 0.07), "fill was \(describe(paint.fill))")
            #expect(isClose(paint.title, toHex: 0xCDC7E0), "title was \(describe(paint.title))")
            #expect(isClose(paint.indicator, toHex: 0x5B5478), "indicator was \(describe(paint.indicator))")
            #expect(paint.titleWeight == .semibold)
        }
    }

    @Test("The title is regular weight when the style does not bold it")
    func titleWeightFollowsTheStyle() {
        var plain = style
        plain.boldsSelectedTitle = false

        for isPaneFocused in [true, false] {
            let paint = SelectedTabPaint(style: plain, isPaneFocused: isPaneFocused, isWindowKey: true)
            #expect(paint.titleWeight == .regular)
        }
    }

    @Test("A color that is not a hex string falls back to a system color instead of failing")
    func malformedHexFallsBackToSystemColors() {
        let broken = SelectedTabStyle(
            fillHex: "not a color",
            inactiveWindowFillHex: "#12",
            unfocusedPaneFillHex: "",
            titleHex: "#GGGGGG",
            unfocusedPaneTitleHex: "",
            indicatorHex: "",
            unfocusedPaneIndicatorHex: "#5B5478"
        )

        let focused = SelectedTabPaint(style: broken, isPaneFocused: true, isWindowKey: true)
        #expect(focused.fill.alphaComponent == 0, "an unreadable fill must paint nothing")
        #expect(focused.title == .labelColor)
        #expect(focused.indicator == .controlAccentColor)

        let unfocused = SelectedTabPaint(style: broken, isPaneFocused: false, isWindowKey: true)
        #expect(unfocused.fill.alphaComponent == 0)
        #expect(unfocused.title == .labelColor)
        #expect(isClose(unfocused.indicator, toHex: 0x5B5478), "a valid neighbor stays valid")
    }

    // MARK: - Configuration

    @Test("The default appearance has no selected tab style, so upstream drawing is unchanged")
    func defaultAppearanceHasNoSelectedTabStyle() {
        #expect(BonsplitConfiguration.Appearance().selectedTabStyle == nil)
        #expect(BonsplitConfiguration.Appearance.default.selectedTabStyle == nil)
        #expect(BonsplitConfiguration.default.appearance.selectedTabStyle == nil)
    }

    @Test("An appearance keeps the style it is given")
    func appearanceKeepsTheStyle() {
        #expect(BonsplitConfiguration.Appearance(selectedTabStyle: style).selectedTabStyle == style)
    }

    @Test("A style defaults to a 2 pt indicator and a bold title")
    func styleDefaults() {
        #expect(style.indicatorThickness == 2)
        #expect(style.boldsSelectedTitle)
    }

    // MARK: - Drawing

    @Test("A styled selected tab keeps full color in an unfocused pane; every other tab still follows the bar")
    func styledSelectedTabIsNotDesaturated() {
        // SwiftUI's saturation is applied by Core Animation, which a bitmap
        // snapshot does not capture, so the rule is checked on its own.
        #expect(TabItemStyling.paintSaturation(hasSelectedTabStyle: true, tabSaturation: 0) == 1)
        #expect(TabItemStyling.paintSaturation(hasSelectedTabStyle: true, tabSaturation: 1) == 1)
        #expect(TabItemStyling.paintSaturation(hasSelectedTabStyle: false, tabSaturation: 0) == 0)
        #expect(TabItemStyling.paintSaturation(hasSelectedTabStyle: false, tabSaturation: 1) == 1)
    }

    @Test("The fill follows pane focus and window key state")
    func fillFollowsFocusAndKeyState() throws {
        let probe = SelectedTabStyle(
            fillHex: "#FF0000",
            inactiveWindowFillHex: "#00FF00",
            unfocusedPaneFillHex: "#0000FF",
            titleHex: "#FFFFFF",
            unfocusedPaneTitleHex: "#FFFFFF",
            indicatorHex: "#FFFF00",
            unfocusedPaneIndicatorHex: "#00FFFF"
        )
        let cases: [(name: String, isFocused: Bool, state: ControlActiveState, expected: String)] = [
            ("focused pane, key window", true, .key, "red"),
            ("focused pane, window not key", true, .inactive, "green"),
            ("unfocused pane, key window", false, .key, "blue"),
            ("unfocused pane, window not key", false, .inactive, "blue")
        ]

        for testCase in cases {
            let bar = try renderTabBar(style: probe, isFocused: testCase.isFocused, controlActiveState: testCase.state)
            let color = try #require(bar.color(at: NSPoint(x: 2, y: Self.barHeight / 2)))
            #expect(probeColorName(color) == testCase.expected, "\(testCase.name): fill was \(describe(color))")
        }
    }

    @Test("A tab bar without a selected tab style does not re-render when its window gains or loses key")
    func unstyledBarIgnoresWindowKeyState() throws {
        let bar = try hostTabBar(style: nil, titles: ["One", "Two"], countsTabEvaluations: true)
        defer { bar.close() }
        try bar.settle(untilQuiet: true)
        #expect(bar.evaluations.count > 0, "the probe must see the first render")
        try bar.warmUp()

        // A dependency on the window state re-renders the bar on every flip. An unrelated late layout
        // update can still land in one flip's window when the machine is busy, so one is let through.
        var rerenderedFlips = 0
        var rerendered = bar.evaluations.count
        for state in [ControlActiveState.inactive, .key, .inactive, .key, .inactive, .key] {
            bar.controlActiveState = state
            try bar.settle(untilQuiet: true)
            if bar.evaluations.count != rerendered { rerenderedFlips += 1 }
            rerendered = bar.evaluations.count
        }
        #expect(rerenderedFlips <= 1, "\(rerenderedFlips) of 6 key changes re-rendered the bar")

        // The selection is something the bar does depend on, so the result above is not a blind probe.
        let beforeSelecting = bar.evaluations.count
        bar.select(tabAt: 1)
        try bar.settle(untilQuiet: true)
        #expect(bar.evaluations.count > beforeSelecting, "selecting a tab must re-render the tabs")
    }

    @Test("A tab bar with a selected tab style repaints when its window gains or loses key")
    func styledBarFollowsWindowKeyState() throws {
        let probe = SelectedTabStyle(
            fillHex: "#FF0000",
            inactiveWindowFillHex: "#00FF00",
            unfocusedPaneFillHex: "#0000FF",
            titleHex: "#FFFFFF",
            unfocusedPaneTitleHex: "#FFFFFF",
            indicatorHex: "#FFFF00",
            unfocusedPaneIndicatorHex: "#00FFFF"
        )
        let bar = try hostTabBar(style: probe, countsTabEvaluations: true)
        defer { bar.close() }
        try bar.settle(untilQuiet: true)
        try bar.warmUp()
        let fill = NSPoint(x: 2, y: Self.barHeight / 2)
        let fillColorName = { try probeColorName(#require(bar.snapshot().color(at: fill))) }
        #expect(try fillColorName() == "red", "key window")

        let evaluated = bar.evaluations.count
        bar.controlActiveState = .inactive
        try bar.settle(untilQuiet: true)
        #expect(bar.evaluations.count > evaluated, "the bar must re-render when its window stops being key")
        #expect(try fillColorName() == "green", "window not key")

        bar.controlActiveState = .key
        try bar.settle(untilQuiet: true)
        #expect(try fillColorName() == "red", "key window again")
    }

    @Test("A bar picks up a selected tab style the host sets after the bar is on screen, and drops it when cleared")
    func styleSetAfterTheBarIsOnScreen() throws {
        let probe = SelectedTabStyle(
            fillHex: "#FF0000",
            inactiveWindowFillHex: "#00FF00",
            unfocusedPaneFillHex: "#0000FF",
            titleHex: "#FFFFFF",
            unfocusedPaneTitleHex: "#FFFFFF",
            indicatorHex: "#FFFF00",
            unfocusedPaneIndicatorHex: "#00FFFF"
        )
        let bar = try hostTabBar(style: nil, countsTabEvaluations: true)
        defer { bar.close() }
        try bar.settle(untilQuiet: true)
        let fill = NSPoint(x: 2, y: Self.barHeight / 2)
        let unstyled = try #require(bar.snapshot().color(at: fill))
        #expect(probeColorName(unstyled) == "other", "upstream fill: \(describe(unstyled))")

        bar.controller.configuration.appearance.selectedTabStyle = probe
        try bar.settle(untilQuiet: true)
        let styled = try #require(bar.snapshot().color(at: fill))
        #expect(probeColorName(styled) == "red", "style set later: \(describe(styled))")

        bar.controller.configuration.appearance.selectedTabStyle = nil
        try bar.settle(untilQuiet: true)
        let cleared = try #require(bar.snapshot().color(at: fill))
        #expect(probeColorName(cleared) == "other", "style cleared: \(describe(cleared))")
    }

    @Test("Setting or clearing the style on a live bar keeps the tab strip alive: same AppKit views, same scroll position")
    func styleToggleKeepsTheTabStripAlive() throws {
        // The tab strip owns the control-key shortcut monitor's lifecycle (`onAppear` starts it,
        // `onDisappear` stops it, and a window reader hands it the host window). Rebuilding the strip
        // runs the new `onAppear` before the old `onDisappear` and leaves the monitor stopped, so a
        // toggle must not rebuild anything. A style that keeps the title regular leaves tab widths
        // alone, so the views and the scroll position are comparable across the toggle.
        var plain = style
        plain.boldsSelectedTitle = false
        let bar = try hostTabBar(
            style: nil,
            titles: (1...12).map { "Terminal \($0)" },
            tabShortcutHints: true,
            countsTabEvaluations: true
        )
        defer { bar.close() }
        try bar.settle(untilQuiet: true)
        try bar.scrollStrip(to: 60)
        try bar.settle(untilQuiet: true)
        let views = bar.bonsplitViews()
        let offset = bar.scrollOffset
        #expect(views.count > 12, "the bar owns its AppKit views: \(views.count)")
        #expect(views.values.contains { $0.hasSuffix("WindowTrackingView") }, "the shortcut hints' window reader exists")
        #expect(offset > 30, "the strip is scrolled: \(offset) pt")

        for (step, newStyle) in [("set", Optional(plain)), ("cleared", nil)] {
            bar.controller.configuration.appearance.selectedTabStyle = newStyle
            try bar.settle(untilQuiet: true)
            let replaced = Set(views.keys).subtracting(bar.bonsplitViews().keys).compactMap { views[$0] }
            #expect(replaced.isEmpty, "style \(step): the bar rebuilt \(replaced.count) views, e.g. \(replaced.prefix(3))")
            #expect(abs(bar.scrollOffset - offset) < 1, "style \(step): scroll offset \(bar.scrollOffset) pt, was \(offset) pt")
        }
    }

    @Test("The control-key shortcut monitor keeps running after the style is set and cleared on a live bar")
    func shortcutMonitorSurvivesStyleToggle() async throws {
        // The monitor re-reads the configured shortcut when the app resigns active, and a changed modifier
        // symbol re-renders the tabs, so a monitor that responds is a monitor that is running. A rebuilt
        // strip starts the new monitor before it stops the old one and leaves it stopped for good.
        var plain = style
        plain.boldsSelectedTitle = false
        let key = "shortcut.selectSurfaceByNumber"
        let saved = UserDefaults.standard.data(forKey: key)
        defer {
            if let saved {
                UserDefaults.standard.set(saved, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        let bar = try hostTabBar(style: nil, titles: ["One", "Two"], tabShortcutHints: true, countsTabEvaluations: true)
        defer { bar.close() }
        try bar.settle(untilQuiet: true)
        try bar.warmUp()

        var usesCommand = false
        let monitorResponds = { () async throws -> Bool in
            // Swapping the strip's views queues main-actor tasks that re-read the shortcut as well
            // (the window reader hands the monitor its window again), so let them finish first.
            for _ in 0..<5 { await Task.yield() }
            try bar.settle(untilQuiet: true)
            usesCommand.toggle()
            let shortcut = #"{"key":"1","command":\#(usesCommand),"shift":false,"option":false,"control":\#(!usesCommand)}"#
            UserDefaults.standard.set(Data(shortcut.utf8), forKey: key)
            let before = bar.evaluations.count
            NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: NSApp)
            // The monitor reacts in a main-actor task, which cannot run until this test yields.
            for _ in 0..<5 { await Task.yield() }
            try bar.settle(untilQuiet: true)
            return bar.evaluations.count > before
        }
        #expect(try await monitorResponds(), "the monitor responds before any toggle")

        bar.controller.configuration.appearance.selectedTabStyle = plain
        try bar.settle(untilQuiet: true)
        #expect(try await monitorResponds(), "the monitor responds after the style is set")

        bar.controller.configuration.appearance.selectedTabStyle = nil
        try bar.settle(untilQuiet: true)
        #expect(try await monitorResponds(), "the monitor responds after the style is cleared")
    }

    @Test("A style set again reads the window's current key state, not the one from before it was cleared")
    func styleSetAgainReadsTheCurrentKeyState() throws {
        let probe = SelectedTabStyle(
            fillHex: "#FF0000",
            inactiveWindowFillHex: "#00FF00",
            unfocusedPaneFillHex: "#0000FF",
            titleHex: "#FFFFFF",
            unfocusedPaneTitleHex: "#FFFFFF",
            indicatorHex: "#FFFF00",
            unfocusedPaneIndicatorHex: "#00FFFF"
        )
        let bar = try hostTabBar(style: probe, countsTabEvaluations: true)
        defer { bar.close() }
        try bar.settle(untilQuiet: true)
        let fill = NSPoint(x: 2, y: Self.barHeight / 2)
        let fillColorName = { try probeColorName(#require(bar.snapshot().color(at: fill))) }
        #expect(try fillColorName() == "red", "key window")

        // With no style nobody is listening to the window, so the last reported state goes stale.
        bar.controller.configuration.appearance.selectedTabStyle = nil
        try bar.settle(untilQuiet: true)
        bar.controlActiveState = .inactive
        try bar.settle(untilQuiet: true)

        bar.controller.configuration.appearance.selectedTabStyle = probe
        try bar.settle(untilQuiet: true)
        #expect(try fillColorName() == "green", "window not key when the style came back")
    }

    @Test("The indicator is drawn on the tab's bottom edge at the style's thickness")
    func indicatorSitsOnTheBottomEdge() throws {
        let probe = SelectedTabStyle(
            fillHex: "#FF0000",
            inactiveWindowFillHex: "#FF0000",
            unfocusedPaneFillHex: "#FF0000",
            titleHex: "#FFFFFF",
            unfocusedPaneTitleHex: "#FFFFFF",
            indicatorHex: "#FFFF00",
            unfocusedPaneIndicatorHex: "#00FFFF",
            indicatorThickness: 3
        )

        for (isFocused, indicator) in [(true, "yellow"), (false, "cyan")] {
            let bar = try renderTabBar(style: probe, isFocused: isFocused)
            let samples: [(name: String, y: CGFloat, expected: String)] = [
                ("top edge", 0.5, "red"),
                ("above the indicator", Self.barHeight - 3.5, "red"),
                ("indicator, 3rd row from the bottom", Self.barHeight - 2.5, indicator),
                ("indicator, 2nd row from the bottom", Self.barHeight - 1.5, indicator),
                ("indicator, bottom row", Self.barHeight - 0.5, indicator)
            ]
            for sample in samples {
                let color = try #require(bar.color(at: NSPoint(x: 3, y: sample.y)))
                #expect(
                    probeColorName(color) == sample.expected,
                    "focused=\(isFocused) \(sample.name): was \(describe(color))"
                )
            }
        }
    }

    @Test("Under a style that bolds the title, a tab keeps its width when it is selected or deselected")
    func boldStyleKeepsTabWidthStable() throws {
        let titles = ["Terminal session", "Terminal session"]
        let selectingFirst = try renderTabBar(style: style, titles: titles, selectedIndex: 0)
        let selectingSecond = try renderTabBar(style: style, titles: titles, selectedIndex: 1)

        // Each tab is measured once selected and once deselected; all four widths must agree.
        let widths = (selectingFirst.tabFrames + selectingSecond.tabFrames).map(\.width)
        let spread = (widths.max() ?? 0) - (widths.min() ?? 0)
        #expect(widths.count == 4)
        #expect(spread < 0.01, "widths (first selected: A B, second selected: A B): \(widths)")
    }

    @Test("A style that bolds the title sizes every tab for a semibold title; a regular style or no style lays out as upstream")
    func boldStyleReservesSemiboldWidth() throws {
        var regular = style
        regular.boldsSelectedTitle = false
        let title = "Terminal session"

        let bold = try renderTabBar(style: style, titles: [title]).tabFrame.width
        let plain = try renderTabBar(style: regular, titles: [title]).tabFrame.width
        let unstyled = try renderTabBar(style: nil, titles: [title]).tabFrame.width

        // The tab grows by what semibold adds to the title, no more and no less.
        let extra = titleWidth(title, weight: .semibold) - titleWidth(title, weight: .regular)
        #expect(extra > 1, "semibold adds \(extra) pt to the title")
        #expect(abs((bold - plain) - extra) < 1.5, "tab grew \(bold - plain) pt, title grows \(extra) pt")
        #expect(abs(plain - unstyled) < 0.01, "regular \(plain) pt, unstyled \(unstyled) pt")
    }

    @Test("A tab that is not selected draws its title once, left-aligned like upstream, in the reserved slot")
    func unselectedTitleIsDrawnOnceAndLeftAligned() throws {
        // The visible title sits over a hidden semibold copy that only sizes the slot. The copy must
        // not be drawn, and the title must stay at the leading edge instead of centering in the slot.
        var regular = style
        regular.boldsSelectedTitle = false
        let titles = ["Terminal", "Terminal"]

        // The first tab is deselected and starts at x = 0 in both bars, so its glyphs rasterize alike.
        // Large type makes semibold several points wider than regular, so centering would show.
        let reserved = try renderTabBar(
            style: style, titles: titles, selectedIndex: 1, barWidth: 480, tabBarHeight: 40, titleFontSize: 24
        )
        let upstream = try renderTabBar(
            style: regular, titles: titles, selectedIndex: 1, barWidth: 480, tabBarHeight: 40, titleFontSize: 24
        )
        let slot = reserved.ink(in: reserved.tabFrames[0])
        let plain = upstream.ink(in: upstream.tabFrames[0])

        #expect(plain.total > 0, "the regular title is drawn")
        #expect(abs(slot.total - plain.total) <= plain.total * 0.05, "ink \(slot.total) against \(plain.total)")
        let slotLeft = try #require(slot.leftmostX)
        let plainLeft = try #require(plain.leftmostX)
        #expect(abs(slotLeft - plainLeft) <= 1, "title starts at \(slotLeft) pt against \(plainLeft) pt")
    }

    @Test("A title longer than the tab is still cut to one line inside it, selected or not")
    func longTitleStaysInsideTheTab() throws {
        let long = String(repeating: "Terminal session ", count: 6)
        let maximum: CGFloat = 140
        let bar = try renderTabBar(style: style, titles: [long, long], selectedIndex: 0, tabMaxWidth: maximum)

        // Both tabs clamp to the maximum, whatever their weight.
        #expect(bar.tabFrames.map(\.width) == [maximum, maximum], "widths: \(bar.tabFrames.map(\.width))")

        // The unselected tab shows no close button, so its trailing padding and accessory slot stay empty.
        let unselected = bar.tabFrames[1]
        let trailing = CGRect(x: unselected.maxX - 22, y: unselected.minY, width: 21, height: unselected.height)
        let spill = bar.colors(in: trailing).filter { components(of: $0).prefix(3).allSatisfy { $0 > 0.2 } }
        #expect(spill.isEmpty, "\(spill.count) pixels of title ink in the trailing accessory slot")
        let ink = bar.colors(in: unselected).filter { components(of: $0).prefix(3).allSatisfy { $0 > 0.2 } }
        #expect(ink.count > 20, "the title is drawn: \(ink.count) pixels")
    }

    @Test("The title is drawn in the style's title color for the focused and the unfocused pane")
    func titleUsesTheStyleColor() throws {
        let probe = SelectedTabStyle(
            fillHex: "#FF0000",
            inactiveWindowFillHex: "#FF0000",
            unfocusedPaneFillHex: "#FF0000",
            titleHex: "#00FF00",
            unfocusedPaneTitleHex: "#0000FF",
            indicatorHex: "#FFFF00",
            unfocusedPaneIndicatorHex: "#FFFF00"
        )

        for (isFocused, expected) in [(true, "green"), (false, "blue")] {
            // Large type leaves glyph interiors that are solid title color, not anti-aliased edges.
            let bar = try renderTabBar(
                style: probe,
                titles: ["MMM"],
                tabBarHeight: 40,
                titleFontSize: 30,
                isFocused: isFocused
            )
            let titlePixels = bar.colors(in: bar.tabFrame).filter { probeColorName($0) == expected }
            #expect(titlePixels.count > 20, "focused=\(isFocused): \(titlePixels.count) \(expected) pixels in the tab")
        }
    }

    // MARK: - Helpers

    private static let barHeight: CGFloat = 30

    /// A snapshot of one rendered pane tab bar. Its pixels are in the display's
    /// color space, so read them with `probeColorName`.
    private struct RenderedTabBar {
        /// Every tab's frame in tab order, in points from the top-left of the bar.
        let tabFrames: [CGRect]
        let selectedIndex: Int
        fileprivate let bounds: CGRect
        fileprivate let bitmap: NSBitmapImageRep

        /// The selected tab's frame.
        var tabFrame: CGRect { tabFrames[selectedIndex] }

        private var pixelsPerPoint: CGSize {
            CGSize(
                width: CGFloat(bitmap.pixelsWide) / bounds.width,
                height: CGFloat(bitmap.pixelsHigh) / bounds.height
            )
        }

        /// The pixel under `point`, in points from the top-left of the bar.
        func color(at point: NSPoint) -> NSColor? {
            let x = Int((point.x * pixelsPerPoint.width).rounded(.down))
            let y = Int((point.y * pixelsPerPoint.height).rounded(.down))
            guard (0..<bitmap.pixelsWide).contains(x), (0..<bitmap.pixelsHigh).contains(y) else { return nil }
            return bitmap.colorAt(x: x, y: y)
        }

        /// Every pixel inside `rect`, with its x in points from the left of the bar.
        func pixels(in rect: CGRect) -> [(x: CGFloat, color: NSColor)] {
            let scale = pixelsPerPoint
            var pixels: [(x: CGFloat, color: NSColor)] = []
            for y in Int((rect.minY * scale.height).rounded(.up))..<Int((rect.maxY * scale.height).rounded(.down)) {
                for x in Int((rect.minX * scale.width).rounded(.up))..<Int((rect.maxX * scale.width).rounded(.down)) {
                    if let color = bitmap.colorAt(x: x, y: y) {
                        pixels.append((CGFloat(x) / scale.width, color))
                    }
                }
            }
            return pixels
        }

        /// Every pixel color inside `rect`.
        func colors(in rect: CGRect) -> [NSColor] {
            pixels(in: rect).map(\.color)
        }

        /// The summed brightness of the lit pixels inside `rect` and the leftmost x, in points, that has
        /// one. Used to judge how a title was drawn over the black bar.
        func ink(in rect: CGRect) -> (total: CGFloat, leftmostX: CGFloat?) {
            let lit = pixels(in: rect)
                .map { (x: $0.x, brightness: Self.brightness(of: $0.color)) }
                .filter { $0.brightness > 0.05 }
            return (lit.reduce(0) { $0 + $1.brightness }, lit.map(\.x).min())
        }

        private static func brightness(of color: NSColor) -> CGFloat {
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            color.getRed(&red, green: &green, blue: &blue, alpha: nil)
            return (red + green + blue) / 3
        }
    }

    /// The window key state a hosted tab bar sees. Changing it re-runs only the host view below.
    @Observable
    fileprivate final class EnvironmentModel {
        var controlActiveState: ControlActiveState

        init(controlActiveState: ControlActiveState) {
            self.controlActiveState = controlActiveState
        }
    }

    /// Applies the model's window key state to the tab bar. The tab bar is built once and stored, so
    /// a change to the model alters only the environment: the tab bar's own view value stays exactly
    /// as it was, as it does when a real window gains or loses key. Replacing the root view instead
    /// would hand SwiftUI a new `TabBarView` with fresh `@State`, and the bar would re-render anyway.
    private struct EnvironmentHost<Content: View>: View {
        let model: EnvironmentModel
        let content: Content

        var body: some View {
            content.environment(\.controlActiveState, model.controlActiveState)
        }
    }

    /// A tab bar on screen whose window key state and selection can change after its first render.
    @MainActor
    private final class HostedTabBar {
        /// Counts tab body evaluations through the host's middle-click hook, which every tab
        /// body calls once. A re-render of the bar moves it; nothing else in the tab bar is observable.
        final class EvaluationCounter {
            var count = 0
        }

        let controller: BonsplitController
        let tabs: [TabItem]
        private(set) var selectedIndex: Int
        let evaluations = EvaluationCounter()
        private let environment: EnvironmentModel
        private let pane: PaneState
        private let window: NSWindow
        private let hostingView: NSHostingView<AnyView>

        var controlActiveState: ControlActiveState {
            get { environment.controlActiveState }
            set { environment.controlActiveState = newValue }
        }

        init(
            controller: BonsplitController,
            pane: PaneState,
            tabs: [TabItem],
            selectedIndex: Int,
            size: NSSize,
            isFocused: Bool,
            controlActiveState: ControlActiveState
        ) {
            self.controller = controller
            self.pane = pane
            self.tabs = tabs
            self.selectedIndex = selectedIndex
            environment = EnvironmentModel(controlActiveState: controlActiveState)
            let tabBar = TabBarView(pane: pane, isFocused: isFocused, showSplitButtons: false)
                .environment(controller)
                .environment(controller.internalController)
            hostingView = NSHostingView(rootView: AnyView(EnvironmentHost(model: environment, content: tabBar)))
            window = NSWindow(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false
            hostingView.frame = NSRect(origin: .zero, size: size)
            hostingView.autoresizingMask = [.width, .height]
            window.contentView?.addSubview(hostingView)
            window.makeKeyAndOrderFront(nil)
        }

        func close() {
            window.orderOut(nil)
        }

        /// Flips the window key state away and back, settling after each, before a test counts evaluations.
        /// SwiftUI runs the bar's body once on the first update after the first render, whatever that
        /// update is (`_printChanges` reports "@self changed"). Spending it here keeps it out of the
        /// count taken around the changes under test.
        func warmUp() throws {
            let original = controlActiveState
            controlActiveState = original == .key ? .inactive : .key
            try settle(untilQuiet: true)
            controlActiveState = original
            try settle(untilQuiet: true)
        }

        /// Selects another tab, a change the tab bar does depend on.
        func select(tabAt index: Int) {
            selectedIndex = index
            pane.selectedTabId = tabs[index].id
        }

        /// The AppKit views Bonsplit created for the bar (the chrome, the hit regions, the drag and hover
        /// layers, the window reader behind the shortcut hints), by identity. SwiftUI keeps them for as
        /// long as the bar's view tree keeps its identity and replaces them when it is rebuilt.
        func bonsplitViews() -> [ObjectIdentifier: String] {
            var views: [ObjectIdentifier: String] = [:]
            for view in SelectedTabStyleTests.descendants(ofType: NSView.self, in: hostingView) {
                let name = String(reflecting: type(of: view))
                if name.hasPrefix("Bonsplit.") {
                    views[ObjectIdentifier(view)] = name
                }
            }
            return views
        }

        private func stripScrollView() -> NSScrollView? {
            SelectedTabStyleTests.descendants(ofType: NSScrollView.self, in: hostingView).first
        }

        /// How far the tab strip is scrolled, in points.
        var scrollOffset: CGFloat {
            stripScrollView()?.contentView.bounds.origin.x ?? 0
        }

        /// Scrolls the tab strip the way a user's scroll gesture would.
        func scrollStrip(to offset: CGFloat) throws {
            let scrollView = try #require(stripScrollView(), "the tab strip has no scroll view")
            NotificationCenter.default.post(name: NSScrollView.willStartLiveScrollNotification, object: scrollView)
            scrollView.contentView.scroll(to: NSPoint(x: offset, y: 0))
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }

        /// Every tab's frame the tab bar has reported so far, in tab order.
        func tabFrames() -> [CGRect] {
            let chrome = SelectedTabStyleTests.descendants(
                ofType: TabBarSelectionChromeView.ChromeNSView.self,
                in: hostingView
            ).first
            let frames = chrome.flatMap { $0.geometryRegistry?.frames(for: tabs.map(\.id), in: $0) } ?? [:]
            return tabs.compactMap { frames[$0.id] }
        }

        /// Runs layout and the run loop until every tab has reported a frame and, when asked, until no
        /// tab body has run for several passes, so later evaluations are the test's own doing.
        func settle(untilQuiet: Bool = false) throws {
            var quietPasses = 0
            var settled = false
            for _ in 0..<300 where !settled {
                let before = evaluations.count
                window.contentView?.layoutSubtreeIfNeeded()
                RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
                quietPasses = evaluations.count == before ? quietPasses + 1 : 0
                settled = tabFrames().count == tabs.count && (!untilQuiet || quietPasses >= 8)
            }
            try #require(settled, "the tab bar never settled")
        }

        func snapshot() throws -> RenderedTabBar {
            let bounds = hostingView.bounds.integral
            let bitmap = try #require(hostingView.bitmapImageRepForCachingDisplay(in: bounds))
            bitmap.size = bounds.size
            hostingView.cacheDisplay(in: bounds, to: bitmap)
            return RenderedTabBar(tabFrames: tabFrames(), selectedIndex: selectedIndex, bounds: bounds, bitmap: bitmap)
        }
    }

    /// Puts a pane with one tab per title, the one at `selectedIndex` selected, on screen under `style`.
    private func hostTabBar(
        style: SelectedTabStyle?,
        titles: [String] = [""],
        selectedIndex: Int = 0,
        barWidth: CGFloat = 320,
        tabBarHeight: CGFloat? = nil,
        titleFontSize: CGFloat = 11,
        tabMaxWidth: CGFloat = 220,
        isFocused: Bool = true,
        controlActiveState: ControlActiveState = .key,
        tabShortcutHints: Bool = false,
        countsTabEvaluations: Bool = false
    ) throws -> HostedTabBar {
        _ = NSApplication.shared
        let tabBarHeight = tabBarHeight ?? Self.barHeight
        let appearance = BonsplitConfiguration.Appearance(
            tabBarHeight: tabBarHeight,
            tabMaxWidth: tabMaxWidth,
            tabTitleFontSize: titleFontSize,
            chromeColors: .init(
                backgroundHex: "#000000",
                tabBarBackgroundHex: "#000000",
                borderHex: "#00000000"
            ),
            selectedTabStyle: style
        )
        let controller = BonsplitController(configuration: BonsplitConfiguration(appearance: appearance))
        controller.tabShortcutHintsEnabled = tabShortcutHints
        let pane = try #require(controller.internalController.rootNode.allPanes.first)
        let tabs = titles.map { TabItem(title: $0, icon: nil) }
        pane.tabs = tabs
        pane.selectedTabId = tabs[selectedIndex].id

        let bar = HostedTabBar(
            controller: controller,
            pane: pane,
            tabs: tabs,
            selectedIndex: selectedIndex,
            size: NSSize(width: barWidth, height: tabBarHeight),
            isFocused: isFocused,
            controlActiveState: controlActiveState
        )
        if countsTabEvaluations {
            let evaluations = bar.evaluations
            controller.tabMiddleClickCapture = { _ in
                evaluations.count += 1
                return AnyView(Color.clear)
            }
        }
        return bar
    }

    /// Renders a pane with one tab per title, the one at `selectedIndex` selected, under `style`,
    /// and snapshots its tab bar.
    private func renderTabBar(
        style: SelectedTabStyle?,
        titles: [String] = [""],
        selectedIndex: Int = 0,
        barWidth: CGFloat = 320,
        tabBarHeight: CGFloat? = nil,
        titleFontSize: CGFloat = 11,
        tabMaxWidth: CGFloat = 220,
        isFocused: Bool = true,
        controlActiveState: ControlActiveState = .key
    ) throws -> RenderedTabBar {
        let bar = try hostTabBar(
            style: style,
            titles: titles,
            selectedIndex: selectedIndex,
            barWidth: barWidth,
            tabBarHeight: tabBarHeight,
            titleFontSize: titleFontSize,
            tabMaxWidth: tabMaxWidth,
            isFocused: isFocused,
            controlActiveState: controlActiveState
        )
        defer { bar.close() }
        // A styled bar learns its window's key state from the probe one update after the first render.
        try bar.settle(untilQuiet: true)
        return try bar.snapshot()
    }

    /// Width of `title` in the system font at the tab bar's default 11 pt and the given weight.
    private func titleWidth(_ title: String, weight: NSFont.Weight) -> CGFloat {
        (title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 11, weight: weight)]).width
    }

    private static func descendants<T: NSView>(ofType type: T.Type, in root: NSView) -> [T] {
        let own = (root as? T).map { [$0] } ?? []
        return own + root.subviews.flatMap { descendants(ofType: type, in: $0) }
    }

    /// Whether `color` is within `tolerance` of the sRGB color `hex` at `alpha`, per channel.
    private func isClose(
        _ color: NSColor,
        toHex hex: UInt32,
        alpha: CGFloat = 1,
        tolerance: CGFloat = 0.01
    ) -> Bool {
        let expected: [CGFloat] = [
            CGFloat((hex >> 16) & 0xFF) / 255,
            CGFloat((hex >> 8) & 0xFF) / 255,
            CGFloat(hex & 0xFF) / 255,
            alpha
        ]
        return zip(components(of: color), expected).allSatisfy { abs($0 - $1) <= tolerance }
    }

    /// Names the pure probe color a snapshot pixel shows, counting a channel as on above 0.75.
    ///
    /// A snapshot pixel is in the display's color space and `NSBitmapImageRep` labels it
    /// as calibrated RGB, so its exact values differ from the sRGB hex that was drawn.
    /// The probe colors differ by whole channels, which survives that shift.
    private func probeColorName(_ color: NSColor) -> String {
        let channels = components(of: color)
        switch (channels[0] > 0.75, channels[1] > 0.75, channels[2] > 0.75) {
        case (true, false, false): return "red"
        case (false, true, false): return "green"
        case (false, false, true): return "blue"
        case (true, true, false): return "yellow"
        case (false, true, true): return "cyan"
        default: return "other"
        }
    }

    private func components(of color: NSColor) -> [CGFloat] {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return [red, green, blue, alpha]
    }

    private func describe(_ color: NSColor) -> String {
        components(of: color).map { String(format: "%.3f", Double($0)) }.joined(separator: " ")
    }
}

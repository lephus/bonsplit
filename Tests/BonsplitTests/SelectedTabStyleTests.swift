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

    @Test("A bold title makes the selected tab wider; a regular title or no style leaves it as upstream draws it")
    func boldTitleWidensTheSelectedTab() throws {
        var regular = style
        regular.boldsSelectedTitle = false
        let title = "Terminal session"

        let bold = try renderTabBar(style: style, title: title).tabFrame.width
        let plain = try renderTabBar(style: regular, title: title).tabFrame.width
        let unstyled = try renderTabBar(style: nil, title: title).tabFrame.width

        #expect(bold > plain, "bold \(bold) pt, regular \(plain) pt")
        #expect(abs(plain - unstyled) < 0.01, "regular \(plain) pt, unstyled \(unstyled) pt")
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
                title: "MMM",
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
        /// The selected tab's frame, in points from the top-left of the bar.
        let tabFrame: CGRect
        fileprivate let bounds: CGRect
        fileprivate let bitmap: NSBitmapImageRep

        /// The pixel under `point`, in points from the top-left of the bar.
        func color(at point: NSPoint) -> NSColor? {
            let x = Int((point.x * CGFloat(bitmap.pixelsWide) / bounds.width).rounded(.down))
            let y = Int((point.y * CGFloat(bitmap.pixelsHigh) / bounds.height).rounded(.down))
            guard (0..<bitmap.pixelsWide).contains(x), (0..<bitmap.pixelsHigh).contains(y) else { return nil }
            return bitmap.colorAt(x: x, y: y)
        }

        /// Every pixel inside `rect`, in points from the top-left of the bar.
        func colors(in rect: CGRect) -> [NSColor] {
            let scaleX = CGFloat(bitmap.pixelsWide) / bounds.width
            let scaleY = CGFloat(bitmap.pixelsHigh) / bounds.height
            let xs = Int((rect.minX * scaleX).rounded(.up))..<Int((rect.maxX * scaleX).rounded(.down))
            let ys = Int((rect.minY * scaleY).rounded(.up))..<Int((rect.maxY * scaleY).rounded(.down))
            return ys.flatMap { y in xs.compactMap { x in bitmap.colorAt(x: x, y: y) } }
        }
    }

    /// Renders a pane whose only tab is selected, under `style`, and snapshots its tab bar.
    private func renderTabBar(
        style: SelectedTabStyle?,
        title: String = "",
        tabBarHeight: CGFloat = SelectedTabStyleTests.barHeight,
        titleFontSize: CGFloat = 11,
        isFocused: Bool = true,
        controlActiveState: ControlActiveState = .key
    ) throws -> RenderedTabBar {
        _ = NSApplication.shared
        let size = NSSize(width: 320, height: tabBarHeight)
        let appearance = BonsplitConfiguration.Appearance(
            tabBarHeight: tabBarHeight,
            tabTitleFontSize: titleFontSize,
            chromeColors: .init(
                backgroundHex: "#000000",
                tabBarBackgroundHex: "#000000",
                borderHex: "#00000000"
            ),
            selectedTabStyle: style
        )
        let controller = BonsplitController(configuration: BonsplitConfiguration(appearance: appearance))
        controller.tabShortcutHintsEnabled = false
        let pane = try #require(controller.internalController.rootNode.allPanes.first)
        let tab = TabItem(title: title, icon: nil)
        pane.tabs = [tab]
        pane.selectedTabId = tab.id

        let hostingView = NSHostingView(
            rootView: TabBarView(pane: pane, isFocused: isFocused, showSplitButtons: false)
                .environment(controller)
                .environment(controller.internalController)
                .environment(\.controlActiveState, controlActiveState)
        )
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        defer { window.orderOut(nil) }
        let contentView = try #require(window.contentView)
        hostingView.frame = NSRect(origin: .zero, size: size)
        hostingView.autoresizingMask = [.width, .height]
        contentView.addSubview(hostingView)
        window.makeKeyAndOrderFront(nil)

        // The indicator is drawn from the tab's measured frame, which arrives a layout pass later.
        var tabFrame: CGRect?
        for _ in 0..<100 where tabFrame == nil {
            contentView.layoutSubtreeIfNeeded()
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
            let chrome = descendants(ofType: TabBarSelectionChromeView.ChromeNSView.self, in: hostingView).first
            tabFrame = chrome.flatMap { $0.geometryRegistry?.frame(for: tab.id, in: $0) }
        }
        let measuredTabFrame = try #require(tabFrame, "the selected tab never reported a frame")

        let bounds = hostingView.bounds.integral
        let bitmap = try #require(hostingView.bitmapImageRepForCachingDisplay(in: bounds))
        bitmap.size = bounds.size
        hostingView.cacheDisplay(in: bounds, to: bitmap)
        return RenderedTabBar(tabFrame: measuredTabFrame, bounds: bounds, bitmap: bitmap)
    }

    private func descendants<T: NSView>(ofType type: T.Type, in root: NSView) -> [T] {
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

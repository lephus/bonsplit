import AppKit
import SwiftUI
import Testing
@testable import Bonsplit

/// A tab carries the agent activity the host gives it, never persists it, and draws the title
/// effect and the activity glyph only when the host also set a title effect style.
@Suite("Tab activity")
@MainActor
struct TabActivityTests {
    /// The ShellX effect palette.
    private let style = TitleEffectStyle(
        workingBaseHex: "#B39550",
        workingHighlightHex: "#FFF3CF",
        glyphWorkingHex: "#E8C468",
        flashHex: "#D6C4FF42",
        highlightStopHexes: ["#F4A7C0", "#F2C879", "#8FD9A8", "#7CC8E8", "#9FB0F5", "#C9A7F2", "#F4A7C0"]
    )

    // MARK: - Model

    @Test("A tab's activity is runtime state: encoding drops it and decoding restores none")
    func tabActivityIsNotEncoded() throws {
        let tab = TabItem(title: "claude", icon: "terminal.fill")
        tab.activity = TabActivity(kind: .highlight, generation: 4, accessibilityLabel: "Skill · brainstorming")

        let data = try JSONEncoder().encode(tab)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(!json.contains("activity"), "encoded tab: \(json)")
        #expect(!json.contains("brainstorming"), "encoded tab: \(json)")

        let decoded = try JSONDecoder().decode(TabItem.self, from: data)
        #expect(decoded.activity == nil)
        #expect(decoded.title == "claude")
        #expect(decoded.id == tab.id)
    }

    @Test("updateTab sets, keeps and clears a tab's activity, and the public tab snapshot reports it")
    func updateTabSetsAndClearsActivity() throws {
        let controller = BonsplitController()
        let tabId = try #require(controller.createTab(title: "claude", icon: "terminal.fill"))
        let working = TabActivity(kind: .working, generation: 0, accessibilityLabel: "Thinking…")
        #expect(controller.tab(tabId)?.activity == nil)

        controller.updateTab(tabId, activity: .some(working))
        #expect(controller.tab(tabId)?.activity == working)

        controller.updateTab(tabId, title: "claude 2")
        #expect(controller.tab(tabId)?.activity == working, "an update without activity keeps it")

        let skill = TabActivity(kind: .highlight, generation: 1, accessibilityLabel: "Skill · review")
        controller.updateTab(tabId, activity: .some(skill))
        #expect(controller.tab(tabId)?.activity == skill)
        let paneId = try #require(controller.allPaneIds.first)
        #expect(controller.tabs(inPane: paneId).first { $0.id == tabId }?.activity == skill)

        controller.updateTab(tabId, activity: .some(nil))
        #expect(controller.tab(tabId)?.activity == nil)
    }

    @Test("A tab activity defaults to generation zero and no spoken label")
    func activityDefaults() {
        let activity = TabActivity(kind: .working)
        #expect(activity.generation == 0)
        #expect(activity.accessibilityLabel == nil)
        #expect(activity != TabActivity(kind: .highlight))
    }

    @Test("A title effect style defaults to the spec's timing")
    func styleDefaults() {
        #expect(style.workingSweepDuration == 2.2)
        #expect(style.highlightCycleDuration == 3.0)
        #expect(style.glyphFrameDuration == 0.18)
        #expect(style.flashRiseDuration == 0.15)
        #expect(style.flashFadeDuration == 0.8)
    }

    @Test("The default appearance has no title effect style; an appearance keeps the one it is given")
    func appearanceTitleEffectStyle() {
        #expect(BonsplitConfiguration.Appearance().titleEffectStyle == nil)
        #expect(BonsplitConfiguration.Appearance.default.titleEffectStyle == nil)
        #expect(BonsplitConfiguration.default.appearance.titleEffectStyle == nil)
        #expect(BonsplitConfiguration.Appearance(titleEffectStyle: style).titleEffectStyle == style)
    }

    @Test("VoiceOver hears the activity after the title only while the tab draws the effect")
    func accessibilityLabelAddsTheActivity() {
        #expect(TabItemStyling.accessibilityLabel(title: "claude", activityLabel: "Thinking…") == "claude, Thinking…")
        #expect(TabItemStyling.accessibilityLabel(title: "claude", activityLabel: nil) == "claude")
        #expect(TabItemStyling.accessibilityLabel(title: "claude", activityLabel: "") == "claude")
    }

    // MARK: - Tab bar

    @Test(
        "The tab bar draws the effect, the glyph and the flash only for a tab with an activity under a title effect style",
        arguments: [(true, true), (true, false), (false, true), (false, false)]
    )
    func effectNeedsActivityAndStyle(hasStyle: Bool, hasActivity: Bool) throws {
        let bar = try HostedBar(style: hasStyle ? style : nil, titles: ["claude", "zsh"])
        defer { bar.close() }
        if hasActivity {
            bar.tabs[0].activity = TabActivity(kind: .working)
        }
        let expected = hasStyle && hasActivity ? 1 : 0
        try bar.settle { $0.effectViewCounts == [expected, expected, expected] }

        #expect(bar.views(TitleEffectView.self).count == expected)
        #expect(bar.views(ActivityGlyphView.self).count == expected)
        #expect(bar.views(ActivityFlashView.self).count == expected)
    }

    @Test("A bar without a title effect style does not re-render a tab when its activity changes")
    func unstyledBarIgnoresActivityChanges() throws {
        for style in [nil, Optional(style)] {
            let bar = try HostedBar(style: style, titles: ["claude", "zsh"], countsTabEvaluations: true)
            defer { bar.close() }
            try bar.settle(untilQuiet: true)
            let before = bar.evaluations.count
            #expect(before > 0, "the probe must see the first render")

            bar.tabs[0].activity = TabActivity(kind: .working, accessibilityLabel: "Thinking…")
            try bar.settle(untilQuiet: true)
            if style == nil {
                #expect(bar.evaluations.count == before, "an unstyled bar re-rendered \(bar.evaluations.count - before) tab bodies")
            } else {
                // The same change on a styled bar does re-render the tab, so the probe above is not blind.
                #expect(bar.evaluations.count > before, "a styled bar must re-render the tab that changed")
            }
        }
    }

    @Test("Clearing a tab's activity removes its effect, glyph and flash")
    func clearingActivityRemovesTheEffect() throws {
        let bar = try HostedBar(style: style, titles: ["claude", "zsh"])
        defer { bar.close() }
        bar.tabs[0].activity = TabActivity(kind: .highlight, generation: 2)
        try bar.settle { $0.views(TitleEffectView.self).count == 1 }

        bar.tabs[0].activity = nil
        try bar.settle { $0.effectViewCounts == [0, 0, 0] }
        #expect(bar.views(TitleEffectView.self).isEmpty)
        #expect(bar.views(ActivityGlyphView.self).isEmpty)
        #expect(bar.views(ActivityFlashView.self).isEmpty)
    }

    @Test("Under a still working effect the title and the glyph, in the icon's place, are drawn in the running color")
    func effectDrawsTheTitleAndTheGlyph() throws {
        let probe = TitleEffectStyle(
            workingBaseHex: "#FF0000",
            workingHighlightHex: "#FF0000",
            glyphWorkingHex: "#00FF00",
            flashHex: "#00000000",
            highlightStopHexes: ["#FF0000", "#FF0000"]
        )
        let titleStart = TabBarMetrics.tabHorizontalPadding + TabBarMetrics.iconSize + TabBarMetrics.contentSpacing / 2
        // The second tab is not selected, so no close button draws in it; its icon and title are grey.
        let plain = try HostedBar(
            style: probe,
            titles: ["One", "MMM"],
            icon: "terminal.fill",
            tabBarHeight: 40,
            titleFontSize: 24
        )
        defer { plain.close() }
        try plain.settle()
        let plainTab = try plain.snapshot().pixels(inTab: 1)
        #expect(plainTab.count(of: "red") == 0)
        #expect(plainTab.count(of: "green") == 0)
        #expect(plainTab.count(of: "light") > 20, "the plain icon and title are drawn in the tab's text color")

        let bar = try HostedBar(
            style: probe,
            titles: ["One", "MMM"],
            icon: "terminal.fill",
            tabBarHeight: 40,
            titleFontSize: 24
        )
        defer { bar.close() }
        bar.tabs[1].activity = TabActivity(kind: .working)
        try bar.settle { $0.views(TitleEffectView.self).count == 1 }
        // Test windows never report themselves visible, so the effect holds its still look.
        let snapshot = try bar.snapshot()
        let title = try snapshot.pixels(inTab: 1, from: titleStart)
        let iconSlot = try snapshot.pixels(inTab: 1, to: titleStart)
        #expect(title.count(of: "green") > 20, "a still working title is drawn in the running color")
        #expect(title.count(of: "red") == 0, "not in the base color the sweep runs over")
        #expect(iconSlot.count(of: "green") > 5, "the glyph is drawn in the icon slot")
        #expect(title.count(of: "light") + iconSlot.count(of: "light") == 0, "neither the icon nor the title text is drawn")
    }

    @Test("Under an effect the real title and icon are not drawn at all, only the effect is")
    func titleIsClearUnderTheEffect() throws {
        // An effect drawn in fully transparent colors leaves nothing to see, unless the title or the icon still draws.
        let invisible = TitleEffectStyle(
            workingBaseHex: "#00000000",
            workingHighlightHex: "#00000000",
            glyphWorkingHex: "#00000000",
            flashHex: "#00000000",
            highlightStopHexes: ["#00000000", "#00000000"]
        )
        let bar = try HostedBar(
            style: invisible,
            titles: ["One", "MMM"],
            icon: "terminal.fill",
            tabBarHeight: 40,
            titleFontSize: 24
        )
        defer { bar.close() }
        bar.tabs[1].activity = TabActivity(kind: .working)
        try bar.settle { $0.views(TitleEffectView.self).count == 1 }

        let tab = try bar.snapshot().pixels(inTab: 1)
        #expect(tab.count(of: "light") == 0, "the clear title and the replaced icon leave no ink")
        #expect(tab.inkBox() == nil)
    }

    @Test("The effect lies exactly over the title: same glyphs, same place, same ellipsis")
    func effectInkMatchesTheTitle() throws {
        // A still working title takes the running color, so every effect color is white.
        let white = TitleEffectStyle(
            workingBaseHex: "#FFFFFF",
            workingHighlightHex: "#FFFFFF",
            glyphWorkingHex: "#FFFFFF",
            flashHex: "#00000000",
            highlightStopHexes: ["#FFFFFF", "#FFFFFF"]
        )
        let titles = ["One", "Terminal session that is far too long to fit"]
        // Past the icon slot, where the icon or the glyph draws, only the title draws, and the selected
        // tab's close button, which neither run changes.
        let titleStart = TabBarMetrics.tabHorizontalPadding + TabBarMetrics.iconSize + TabBarMetrics.contentSpacing / 2
        for (index, title) in titles.enumerated() {
            let plain = try HostedBar(style: white, titles: titles, icon: "terminal.fill", tabMaxWidth: 160)
            defer { plain.close() }
            try plain.settle()
            let plainInk = try plain.snapshot().pixels(inTab: index, from: titleStart).inkBox()

            let bar = try HostedBar(style: white, titles: titles, icon: "terminal.fill", tabMaxWidth: 160)
            defer { bar.close() }
            bar.tabs[index].activity = TabActivity(kind: .working)
            try bar.settle { $0.views(TitleEffectView.self).count == 1 }
            let effectInk = try bar.snapshot().pixels(inTab: index, from: titleStart).inkBox()

            let plainBox = try #require(plainInk, "\(title): no title ink")
            let effectBox = try #require(effectInk, "\(title): no effect ink")
            #expect(abs(plainBox.minX - effectBox.minX) <= 1, "\(title): left \(plainBox) vs \(effectBox)")
            #expect(abs(plainBox.maxX - effectBox.maxX) <= 1, "\(title): right \(plainBox) vs \(effectBox)")
            #expect(abs(plainBox.minY - effectBox.minY) <= 1, "\(title): top \(plainBox) vs \(effectBox)")
            #expect(abs(plainBox.maxY - effectBox.maxY) <= 1, "\(title): bottom \(plainBox) vs \(effectBox)")
        }
    }

    @Test("The glyph takes the icon's slot, so a tab with an icon keeps its width while it shows an activity")
    func glyphKeepsTheTabWidth() throws {
        let titles = ["claude", "zsh"]
        let plain = try HostedBar(style: style, titles: titles, icon: "terminal.fill")
        defer { plain.close() }
        try plain.settle()

        let bar = try HostedBar(style: style, titles: titles, icon: "terminal.fill")
        defer { bar.close() }
        bar.tabs[0].activity = TabActivity(kind: .working)
        bar.tabs[1].activity = TabActivity(kind: .highlight, generation: 1)
        try bar.settle { $0.views(ActivityGlyphView.self).count == 2 }

        #expect(bar.tabFrames().map(\.width) == plain.tabFrames().map(\.width))
    }

    @Test("A highlight that was already shown does not flash again when the effect comes back after a pause")
    func highlightDoesNotFlashAgainAfterAPause() throws {
        let bar = try HostedBar(style: style, titles: ["claude"])
        defer { bar.close() }
        let skill = TabActivity(kind: .highlight, generation: 5)
        bar.tabs[0].activity = skill
        try bar.settle { $0.views(ActivityFlashView.self).count == 1 }
        let first = try #require(bar.views(ActivityFlashView.self).first)
        #expect(first.flashRequestCount == 1, "a new highlight asks for its flash")

        // The agent stops to ask for permission: no effect while it waits.
        bar.tabs[0].activity = nil
        try bar.settle { $0.views(ActivityFlashView.self).isEmpty }
        bar.tabs[0].activity = skill
        try bar.settle { $0.views(ActivityFlashView.self).count == 1 }
        let resumed = try #require(bar.views(ActivityFlashView.self).first)
        #expect(resumed !== first, "SwiftUI built a new flash view")
        #expect(resumed.flashedGeneration == 5, "the tab told the new view what it already showed")
        #expect(resumed.flashRequestCount == 0, "the same skill must not flash again")

        bar.tabs[0].activity = TabActivity(kind: .highlight, generation: 6)
        try bar.settle { $0.views(ActivityFlashView.self).first?.flashRequestCount == 1 }
        #expect(bar.views(ActivityFlashView.self).first?.flashRequestCount == 1, "a new skill flashes")
    }

    @Test("The flash covers the whole tab, wherever the tab is in the bar")
    func flashCoversTheWholeTab() throws {
        let bar = try HostedBar(style: style, titles: ["claude", "Terminal session"], icon: "terminal.fill")
        defer { bar.close() }
        bar.tabs[1].activity = TabActivity(kind: .highlight, generation: 1)
        try bar.settle { $0.views(ActivityFlashView.self).count == 1 }

        let flash = try #require(bar.views(ActivityFlashView.self).first)
        let flashFrame = flash.convert(flash.bounds, to: nil)
        let tabFrame = try #require(bar.tabFramesInWindow().last)
        #expect(abs(flashFrame.minX - tabFrame.minX) < 0.5, "left: \(flashFrame) vs \(tabFrame)")
        #expect(abs(flashFrame.maxX - tabFrame.maxX) < 0.5, "right: \(flashFrame) vs \(tabFrame)")
        #expect(abs(flashFrame.minY - tabFrame.minY) < 0.5, "bottom: \(flashFrame) vs \(tabFrame)")
        #expect(abs(flashFrame.maxY - tabFrame.maxY) < 0.5, "top: \(flashFrame) vs \(tabFrame)")
    }

    @Test("The flash lies above the tab's fill and below its title")
    func flashSitsBetweenTheFillAndTheTitle() throws {
        // An opaque blue fill, an opaque green wash and a red title: a still highlight shows its stops, so the title is red.
        let fill = SelectedTabStyle(
            fillHex: "#0000FF",
            inactiveWindowFillHex: "#0000FF",
            unfocusedPaneFillHex: "#0000FF",
            titleHex: "#FFFFFF",
            unfocusedPaneTitleHex: "#FFFFFF",
            indicatorHex: "#0000FF",
            unfocusedPaneIndicatorHex: "#0000FF"
        )
        let probe = TitleEffectStyle(
            workingBaseHex: "#FF0000",
            workingHighlightHex: "#FF0000",
            glyphWorkingHex: "#FF0000",
            flashHex: "#00FF00",
            highlightStopHexes: ["#FF0000", "#FF0000"]
        )
        let bar = try HostedBar(
            style: probe,
            titles: ["MMM"],
            icon: "terminal.fill",
            tabBarHeight: 40,
            titleFontSize: 24,
            selectedTabStyle: fill
        )
        defer { bar.close() }
        bar.tabs[0].activity = TabActivity(kind: .highlight, generation: 1)
        try bar.settle { $0.views(ActivityFlashView.self).count == 1 }
        let between = try bar.snapshot().pixels(inTab: 0)
        #expect(between.count(of: "green") == 0, "between flashes the wash draws nothing")
        #expect(between.count(of: "blue") > 200, "the fill shows")

        // Hold the wash at its peak, as a flash does halfway through.
        let flash = try #require(bar.views(ActivityFlashView.self).first)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        flash.flashLayer.opacity = 1
        CATransaction.commit()
        let peak = try bar.snapshot().pixels(inTab: 0)
        #expect(peak.count(of: "green") > 200, "the wash covers the fill")
        #expect(peak.count(of: "green") > 5 * peak.count(of: "blue"), "only the edge chrome stays blue: \(peak.count(of: "blue"))")
        #expect(peak.count(of: "red") > 20, "the title stays on top of the wash")
    }

    @Test("The effect overlay does not take clicks away from the tab")
    func effectDoesNotTakeClicks() throws {
        let bar = try HostedBar(style: style, titles: ["claude", "zsh"])
        defer { bar.close() }
        bar.tabs[0].activity = TabActivity(kind: .working)
        try bar.settle { $0.effectViewCounts == [1, 1, 1] }

        var effects: [NSView] = bar.views(TitleEffectView.self)
        effects += bar.views(ActivityGlyphView.self) as [NSView]
        effects += bar.views(ActivityFlashView.self) as [NSView]
        #expect(effects.count == 3)
        for effect in effects {
            let center = NSPoint(x: effect.bounds.midX, y: effect.bounds.midY)
            let hit = bar.hitTest(effect.convert(center, to: nil))
            #expect(hit !== effect, "\(type(of: effect)) took the click")
            #expect(hit !== effect.superview, "the host of \(type(of: effect)) took the click")
            #expect(hit.map { !$0.isDescendant(of: effect) } ?? true)
        }
    }

    // MARK: - Helpers

    /// One rendered tab's pixels, named by probe color.
    @MainActor
    private struct TabPixels {
        let pixels: [(x: Int, y: Int, color: NSColor)]

        func count(of name: String) -> Int {
            pixels.filter { TabActivityTests.colorName($0.color) == name }.count
        }

        /// The bounding box, in pixels, of the grey and white ink brighter than the dark bar. Colored
        /// chrome, such as the selection indicator, is left out.
        func inkBox() -> (minX: Int, maxX: Int, minY: Int, maxY: Int)? {
            let lit = pixels.filter {
                TabActivityTests.brightness($0.color) > 0.3 && TabActivityTests.isNeutral($0.color)
            }
            guard let minX = lit.map(\.x).min(), let maxX = lit.map(\.x).max(),
                  let minY = lit.map(\.y).min(), let maxY = lit.map(\.y).max() else { return nil }
            return (minX, maxX, minY, maxY)
        }
    }

    /// A snapshot of a hosted tab bar.
    @MainActor
    private struct Snapshot {
        let bitmap: NSBitmapImageRep
        let bounds: CGRect
        let tabFrames: [CGRect]

        /// Every pixel inside the tab at `index`, between `from` and `to` points from the tab's leading edge.
        func pixels(inTab index: Int, from start: CGFloat = 0, to end: CGFloat? = nil) throws -> TabPixels {
            let tabFrame = try #require(tabFrames.indices.contains(index) ? tabFrames[index] : nil)
            var frame = tabFrame
            frame.origin.x += start
            frame.size.width = min(end ?? tabFrame.width, tabFrame.width) - start
            let scaleX = CGFloat(bitmap.pixelsWide) / bounds.width
            let scaleY = CGFloat(bitmap.pixelsHigh) / bounds.height
            var pixels: [(x: Int, y: Int, color: NSColor)] = []
            for y in Int((frame.minY * scaleY).rounded(.up))..<Int((frame.maxY * scaleY).rounded(.down)) {
                for x in Int((frame.minX * scaleX).rounded(.up))..<Int((frame.maxX * scaleX).rounded(.down)) {
                    if let color = bitmap.colorAt(x: x, y: y) {
                        pixels.append((x, y, color))
                    }
                }
            }
            return TabPixels(pixels: pixels)
        }
    }

    /// A pane tab bar on screen over a black bar.
    @MainActor
    private final class HostedBar {
        /// Counts tab body evaluations through the host's middle-click hook, which every tab body calls once.
        final class EvaluationCounter {
            var count = 0
        }

        let controller: BonsplitController
        let tabs: [TabItem]
        let evaluations = EvaluationCounter()
        private let window: NSWindow
        private let hostingView: NSHostingView<AnyView>

        init(
            style: TitleEffectStyle?,
            titles: [String],
            icon: String? = nil,
            tabBarHeight: CGFloat = 30,
            titleFontSize: CGFloat = 11,
            tabMaxWidth: CGFloat = 220,
            selectedTabStyle: SelectedTabStyle? = nil,
            countsTabEvaluations: Bool = false
        ) throws {
            _ = NSApplication.shared
            let appearance = BonsplitConfiguration.Appearance(
                tabBarHeight: tabBarHeight,
                tabMaxWidth: tabMaxWidth,
                tabTitleFontSize: titleFontSize,
                chromeColors: .init(backgroundHex: "#000000", tabBarBackgroundHex: "#000000", borderHex: "#00000000"),
                selectedTabStyle: selectedTabStyle,
                titleEffectStyle: style
            )
            controller = BonsplitController(configuration: BonsplitConfiguration(appearance: appearance))
            if countsTabEvaluations {
                let evaluations = evaluations
                controller.tabMiddleClickCapture = { _ in
                    evaluations.count += 1
                    return AnyView(Color.clear)
                }
            }
            let pane = try #require(controller.internalController.rootNode.allPanes.first)
            tabs = titles.map { TabItem(title: $0, icon: icon) }
            pane.tabs = tabs
            pane.selectedTabId = tabs[0].id
            let tabBar = TabBarView(pane: pane, isFocused: true, showSplitButtons: false)
                .environment(controller)
                .environment(controller.internalController)
            hostingView = NSHostingView(rootView: AnyView(tabBar))
            let size = NSSize(width: 480, height: tabBarHeight)
            window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            hostingView.frame = NSRect(origin: .zero, size: size)
            window.contentView?.addSubview(hostingView)
            window.makeKeyAndOrderFront(nil)
        }

        func close() {
            window.orderOut(nil)
        }

        /// Every view of `type` in the bar.
        func views<View: NSView>(_ type: View.Type) -> [View] {
            TabActivityTests.descendants(ofType: type, in: hostingView)
        }

        /// How many title effects, glyphs and flashes the bar holds, in that order.
        var effectViewCounts: [Int] {
            [views(TitleEffectView.self).count, views(ActivityGlyphView.self).count, views(ActivityFlashView.self).count]
        }

        /// Every tab's frame in window coordinates, in tab order.
        func tabFramesInWindow() -> [CGRect] {
            guard let chrome = TabActivityTests.descendants(
                ofType: TabBarSelectionChromeView.ChromeNSView.self,
                in: hostingView
            ).first else { return [] }
            return tabFrames().map { chrome.convert($0, to: nil) }
        }

        /// The view AppKit would deliver a click at `windowPoint` to.
        func hitTest(_ windowPoint: NSPoint) -> NSView? {
            guard let contentView = window.contentView else { return nil }
            return contentView.hitTest(contentView.superview?.convert(windowPoint, from: nil) ?? windowPoint)
        }

        /// Runs layout and the run loop until every tab reported a frame and `condition` holds and, when
        /// asked, until no tab body has run for several passes.
        func settle(untilQuiet: Bool = false, until condition: (HostedBar) -> Bool = { _ in true }) throws {
            var settled = false
            var quietPasses = 0
            for _ in 0..<300 where !settled {
                let before = evaluations.count
                window.contentView?.layoutSubtreeIfNeeded()
                RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
                quietPasses = evaluations.count == before ? quietPasses + 1 : 0
                settled = tabFrames().count == tabs.count && condition(self) && (!untilQuiet || quietPasses >= 8)
            }
            try #require(settled, "the tab bar never settled")
            // A few more passes let the last layout land in the layers.
            for _ in 0..<3 {
                window.contentView?.layoutSubtreeIfNeeded()
                RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
            }
        }

        /// Every tab's frame the tab bar has reported so far, in tab order.
        func tabFrames() -> [CGRect] {
            let chrome = TabActivityTests.descendants(
                ofType: TabBarSelectionChromeView.ChromeNSView.self,
                in: hostingView
            ).first
            let frames = chrome.flatMap { $0.geometryRegistry?.frames(for: tabs.map(\.id), in: $0) } ?? [:]
            return tabs.compactMap { frames[$0.id] }
        }

        func snapshot() throws -> Snapshot {
            let bounds = hostingView.bounds.integral
            let bitmap = try #require(hostingView.bitmapImageRepForCachingDisplay(in: bounds))
            bitmap.size = bounds.size
            hostingView.cacheDisplay(in: bounds, to: bitmap)
            return Snapshot(bitmap: bitmap, bounds: bounds, tabFrames: tabFrames())
        }
    }

    private static func descendants<View: NSView>(ofType type: View.Type, in root: NSView) -> [View] {
        let own = (root as? View).map { [$0] } ?? []
        return own + root.subviews.flatMap { descendants(ofType: type, in: $0) }
    }

    /// Names a snapshot pixel: a probe color with channels on above 0.75, `light` for a bright
    /// grey title, `other` for anything else. Snapshot pixels are in the display's color space,
    /// which keeps whole channels apart.
    fileprivate static func colorName(_ color: NSColor) -> String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: nil)
        switch (red > 0.75, green > 0.75, blue > 0.75) {
        case (true, false, false): return "red"
        case (false, true, false): return "green"
        case (false, false, true): return "blue"
        default:
            let channels = [red, green, blue]
            let spread = (channels.max() ?? 0) - (channels.min() ?? 0)
            return spread < 0.12 && (channels.min() ?? 0) > 0.35 ? "light" : "other"
        }
    }

    fileprivate static func isNeutral(_ color: NSColor) -> Bool {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: nil)
        return max(red, green, blue) - min(red, green, blue) < 0.12
    }

    fileprivate static func brightness(_ color: NSColor) -> CGFloat {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: nil)
        return (red + green + blue) / 3
    }
}

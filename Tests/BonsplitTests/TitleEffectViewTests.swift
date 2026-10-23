import AppKit
import QuartzCore
import SwiftUI
import Testing
@testable import Bonsplit

/// The title effect and the activity glyph run only Core Animation animations, and only while
/// they can be seen and the user allows motion; otherwise they hold a still look that keeps the
/// title readable.
@Suite("Title effect views")
@MainActor
struct TitleEffectViewTests {
    /// Visibility and motion that a test flips, then announces with the system notification.
    final class FakeEnvironment: TitleEffectEnvironment {
        var reducesMotion = false
        var visible = true

        func isVisible(_ view: NSView) -> Bool {
            visible
        }
    }

    /// The ShellX effect palette.
    private let style = TitleEffectStyle(
        workingBaseHex: "#B39550",
        workingHighlightHex: "#FFF3CF",
        glyphWorkingHex: "#E8C468",
        flashHex: "#D6C4FF42",
        highlightStopHexes: ["#F4A7C0", "#F2C879", "#8FD9A8", "#7CC8E8", "#9FB0F5", "#C9A7F2", "#F4A7C0"]
    )

    // MARK: - Title effect: animations

    @Test("A working title on screen sweeps a highlight across it, left to right, once per sweep duration")
    func workingInstallsSweep() throws {
        let environment = FakeEnvironment()
        let host = TitleHost(environment: environment)
        defer { host.close() }

        host.view.configure(text: title("Terminal"), maximumNumberOfLines: 1, kind: .working, style: style)

        let sweep = try #require(host.view.gradientLayer.animation(forKey: TitleEffectView.sweepAnimationKey))
        #expect(host.view.gradientLayer.animation(forKey: TitleEffectView.flowAnimationKey) == nil)
        #expect(abs(sweep.duration - style.workingSweepDuration) < 0.001)
        #expect(sweep.repeatCount == .infinity)
        let start = try #require(Self.startPointTravel(of: sweep))
        #expect(start.from < start.to, "the highlight must travel left to right: \(start)")
        #expect(!host.view.gradientLayer.isHidden)
    }

    @Test("A highlighted title flows through its colors, left to right, once per cycle duration")
    func highlightInstallsFlow() throws {
        let environment = FakeEnvironment()
        let host = TitleHost(environment: environment)
        defer { host.close() }

        host.view.configure(text: title("Terminal"), maximumNumberOfLines: 1, kind: .highlight, style: style)

        let flow = try #require(host.view.gradientLayer.animation(forKey: TitleEffectView.flowAnimationKey))
        #expect(host.view.gradientLayer.animation(forKey: TitleEffectView.sweepAnimationKey) == nil)
        #expect(abs(flow.duration - style.highlightCycleDuration) < 0.001)
        #expect(flow.repeatCount == .infinity)
        let start = try #require(Self.startPointTravel(of: flow))
        #expect(start.from < start.to, "the colors must flow left to right: \(start)")
        #expect(animationKeys(host.view.gradientLayer) == [TitleEffectView.flowAnimationKey], "the title has no flash of its own")
    }

    @Test("Switching between working and highlight swaps the sweep for the flow and back")
    func kindChangeSwapsAnimations() {
        let environment = FakeEnvironment()
        let host = TitleHost(environment: environment)
        defer { host.close() }

        host.view.configure(text: title("Terminal"), maximumNumberOfLines: 1, kind: .working, style: style)
        host.view.configure(text: title("Terminal"), maximumNumberOfLines: 1, kind: .highlight, style: style)
        #expect(animationKeys(host.view.gradientLayer) == [TitleEffectView.flowAnimationKey])

        host.view.configure(text: title("Terminal"), maximumNumberOfLines: 1, kind: .working, style: style)
        #expect(animationKeys(host.view.gradientLayer) == [TitleEffectView.sweepAnimationKey])
    }

    @Test("With Reduce Motion nothing moves: a working title holds the running color, a highlighted one a still pastel gradient")
    func reduceMotionStopsAnimations() throws {
        let environment = FakeEnvironment()
        let host = TitleHost(environment: environment)
        defer { host.close() }
        host.view.configure(text: title("Terminal"), maximumNumberOfLines: 1, kind: .working, style: style)
        #expect(host.view.gradientLayer.animation(forKey: TitleEffectView.sweepAnimationKey) != nil)

        environment.reducesMotion = true
        Self.announceDisplayOptionsChange()

        #expect(animationKeys(host.view.gradientLayer).isEmpty)
        #expect(!host.view.gradientLayer.isHidden, "the title must still be drawn")
        #expect(host.view.textMaskLayer.contents != nil, "the mask still holds the text")
        #expect(try inkCount(of: host.view) > 20, "the mask has the title's glyphs")
        let workingColors = try #require(host.view.gradientLayer.colors as? [CGColor])
        #expect(
            workingColors.allSatisfy { isClose($0, toHex: 0xE8C468) },
            "a still working title is the running color, the glyph's, not the base color"
        )

        host.view.configure(text: title("Terminal"), maximumNumberOfLines: 1, kind: .highlight, style: style)
        #expect(animationKeys(host.view.gradientLayer).isEmpty)
        let highlightColors = try #require(host.view.gradientLayer.colors as? [CGColor])
        #expect(highlightColors.contains { isClose($0, toHex: 0xF4A7C0) })
        #expect(highlightColors.contains { isClose($0, toHex: 0x8FD9A8) }, "a still highlight keeps its pastel gradient")

        environment.reducesMotion = false
        Self.announceDisplayOptionsChange()
        #expect(host.view.gradientLayer.animation(forKey: TitleEffectView.flowAnimationKey) != nil, "motion comes back")
    }

    @Test("A working title that cannot be seen holds the running color too, and sweeps again when it can")
    func hiddenViewPausesAnimations() throws {
        let environment = FakeEnvironment()
        let host = TitleHost(environment: environment)
        defer { host.close() }
        host.view.configure(text: title("Terminal"), maximumNumberOfLines: 1, kind: .working, style: style)

        environment.visible = false
        host.announceOcclusionChange()
        #expect(animationKeys(host.view.gradientLayer).isEmpty)
        #expect(!host.view.gradientLayer.isHidden, "a paused title is still drawn")
        let stillColors = try #require(host.view.gradientLayer.colors as? [CGColor])
        #expect(stillColors.allSatisfy { isClose($0, toHex: 0xE8C468) })

        environment.visible = true
        host.announceOcclusionChange()
        #expect(animationKeys(host.view.gradientLayer) == [TitleEffectView.sweepAnimationKey])
    }

    @Test("An inactive presentation pauses the effect")
    func inactivePresentationPausesAnimations() {
        let environment = FakeEnvironment()
        let host = TitleHost(environment: environment)
        defer { host.close() }
        host.view.configure(text: title("Terminal"), maximumNumberOfLines: 1, kind: .highlight, style: style)

        host.view.isPresentationActive = false
        #expect(animationKeys(host.view.gradientLayer).isEmpty)

        host.view.isPresentationActive = true
        #expect(animationKeys(host.view.gradientLayer) == [TitleEffectView.flowAnimationKey])
    }

    @Test("Without a kind the effect is hidden and still")
    func nilKindClearsEffect() {
        let environment = FakeEnvironment()
        let host = TitleHost(environment: environment)
        defer { host.close() }
        host.view.configure(text: title("Terminal"), maximumNumberOfLines: 1, kind: .highlight, style: style)

        host.view.configure(text: title("Terminal"), maximumNumberOfLines: 1, kind: nil, style: style)

        #expect(host.view.gradientLayer.isHidden)
        #expect(animationKeys(host.view.gradientLayer).isEmpty)
    }

    // MARK: - Activity flash

    @Test("A new highlight generation washes the whole view once in the flash color: a rise, then a fade")
    func flashPlaysOncePerGeneration() throws {
        let environment = FakeEnvironment()
        let host = FlashHost(environment: environment)
        defer { host.close() }

        host.view.configure(kind: .highlight, generation: 1, style: style)

        let flash = try #require(
            host.view.flashLayer.animation(forKey: ActivityFlashView.flashAnimationKey) as? CAKeyframeAnimation
        )
        let total = style.flashRiseDuration + style.flashFadeDuration
        #expect(flash.keyPath == "opacity")
        #expect(flash.values?.compactMap { ($0 as? NSNumber)?.doubleValue } == [0, 1, 0])
        #expect(abs((flash.keyTimes?[1].doubleValue ?? 0) - style.flashRiseDuration / total) < 0.001, "the peak comes after the rise")
        #expect(abs(flash.duration - total) < 0.001)
        #expect(flash.repeatCount == 0, "the flash plays one beat")
        #expect(host.view.flashLayer.frame == host.view.bounds, "the wash covers the whole view")
        #expect(host.view.flashLayer.opacity == 0, "between flashes the view draws nothing")
        let color = try #require(host.view.flashLayer.backgroundColor)
        #expect(isClose(color, toHex: 0xD6C4FF))
        #expect(abs(color.alpha - CGFloat(0x42) / 255) < 0.01, "the flash color keeps its own alpha")
        #expect(host.view.flashCount == 1)
        #expect(host.view.flashedGeneration == 1)

        host.view.configure(kind: .highlight, generation: 1, style: style)
        #expect(host.view.flashCount == 1, "the same generation must not flash again")

        host.view.configure(kind: .working, generation: 0, style: style)
        host.view.configure(kind: nil, generation: 0, style: style)
        host.view.configure(kind: .highlight, generation: 1, style: style)
        #expect(host.view.flashCount == 1, "returning to the same generation after working or a pause must not flash again")

        host.view.configure(kind: .highlight, generation: 2, style: style)
        #expect(host.view.flashCount == 2, "a new generation flashes again")
    }

    @Test("Working or no activity never flashes")
    func onlyHighlightsFlash() {
        let environment = FakeEnvironment()
        let host = FlashHost(environment: environment)
        defer { host.close() }

        host.view.configure(kind: .working, generation: 5, style: style)
        host.view.configure(kind: nil, generation: 6, style: style)

        #expect(animationKeys(host.view.flashLayer).isEmpty)
        #expect(host.view.flashRequestCount == 0)
        #expect(host.view.flashedGeneration == nil)
    }

    @Test("A host that sets the flashed generation before configuring does not get that generation's flash")
    func seededGenerationDoesNotFlash() {
        let environment = FakeEnvironment()
        let host = FlashHost(environment: environment)
        defer { host.close() }

        host.view.flashedGeneration = 3
        host.view.configure(kind: .highlight, generation: 3, style: style)
        #expect(animationKeys(host.view.flashLayer).isEmpty)
        #expect(host.view.flashRequestCount == 0)

        host.view.configure(kind: .highlight, generation: 4, style: style)
        #expect(host.view.flashCount == 1, "the next generation flashes")
        #expect(host.view.flashedGeneration == 4)
    }

    @Test("Reduce Motion never flashes, not even once motion comes back")
    func reduceMotionNeverFlashes() {
        let environment = FakeEnvironment()
        environment.reducesMotion = true
        let host = FlashHost(environment: environment)
        defer { host.close() }

        host.view.configure(kind: .highlight, generation: 7, style: style)
        #expect(animationKeys(host.view.flashLayer).isEmpty)
        #expect(host.view.flashRequestCount == 1, "the generation is still taken")

        environment.reducesMotion = false
        Self.announceDisplayOptionsChange()
        #expect(animationKeys(host.view.flashLayer).isEmpty, "a skipped flash does not play late")
        #expect(host.view.flashCount == 0)
    }

    @Test("A highlight that starts while the view cannot be seen does not flash later")
    func flashIsSkippedWhileNotVisible() {
        let environment = FakeEnvironment()
        environment.visible = false
        let host = FlashHost(environment: environment)
        defer { host.close() }

        host.view.configure(kind: .highlight, generation: 4, style: style)
        #expect(animationKeys(host.view.flashLayer).isEmpty)

        environment.visible = true
        host.announceOcclusionChange()
        #expect(animationKeys(host.view.flashLayer).isEmpty, "the flash belongs to the start of the highlight")
        #expect(host.view.flashCount == 0)
    }

    @Test("A playing flash stops when the view can no longer be seen or is no longer presented")
    func playingFlashStops() {
        let environment = FakeEnvironment()
        let host = FlashHost(environment: environment)
        defer { host.close() }

        host.view.configure(kind: .highlight, generation: 1, style: style)
        #expect(animationKeys(host.view.flashLayer) == [ActivityFlashView.flashAnimationKey])
        environment.visible = false
        host.announceOcclusionChange()
        #expect(animationKeys(host.view.flashLayer).isEmpty)

        environment.visible = true
        host.announceOcclusionChange()
        host.view.configure(kind: .highlight, generation: 2, style: style)
        #expect(animationKeys(host.view.flashLayer) == [ActivityFlashView.flashAnimationKey])
        host.view.isPresentationActive = false
        #expect(animationKeys(host.view.flashLayer).isEmpty)

        host.view.configure(kind: .highlight, generation: 3, style: style)
        host.view.isPresentationActive = true
        #expect(animationKeys(host.view.flashLayer).isEmpty, "an inactive view skips its flash for good")
        #expect(host.view.flashCount == 2)
    }

    @Test("A view configured before it is on screen plays its flash once it lands in a window")
    func flashWaitsForTheWindow() {
        let environment = FakeEnvironment()
        let view = ActivityFlashView(environment: environment)
        view.frame = NSRect(x: 0, y: 0, width: 160, height: 30)
        view.configure(kind: .highlight, generation: 1, style: style)
        #expect(view.flashCount == 0, "nothing plays off screen")

        let host = FlashHost(environment: environment, view: view)
        defer { host.close() }
        #expect(view.flashCount == 1)
        #expect(view.flashLayer.animation(forKey: ActivityFlashView.flashAnimationKey) != nil)
    }

    @Test("The wash follows the corner radius a host gives it")
    func flashFollowsTheCornerRadius() {
        let host = FlashHost(environment: FakeEnvironment())
        defer { host.close() }
        #expect(host.view.flashLayer.cornerRadius == 0, "square like a tab by default")

        host.view.cornerRadius = 7
        #expect(host.view.flashLayer.cornerRadius == 7)
    }

    // MARK: - Title effect: the text mask

    @Test("The mask is drawn again only when the text, its font, the size or the line limit changes")
    func maskRendersOnlyWhenTextChanges() {
        let environment = FakeEnvironment()
        let host = TitleHost(environment: environment)
        defer { host.close() }

        host.view.configure(text: title("Terminal"), maximumNumberOfLines: 1, kind: .working, style: style)
        #expect(host.view.maskRenderCount == 1)

        host.view.configure(text: title("Terminal"), maximumNumberOfLines: 1, kind: .highlight, style: style)
        host.view.isPresentationActive = false
        host.view.isPresentationActive = true
        host.view.layoutSubtreeIfNeeded()
        #expect(host.view.maskRenderCount == 1, "kind, presentation and layout passes reuse the mask")

        host.view.configure(text: title("Terminal 2"), maximumNumberOfLines: 1, kind: .highlight, style: style)
        #expect(host.view.maskRenderCount == 2, "new text")

        host.view.configure(
            text: title("Terminal 2", weight: .semibold),
            maximumNumberOfLines: 1,
            kind: .highlight,
            style: style
        )
        #expect(host.view.maskRenderCount == 3, "new font")

        host.view.configure(text: title("Terminal 2", weight: .semibold), maximumNumberOfLines: 2, kind: .highlight, style: style)
        #expect(host.view.maskRenderCount == 4, "new line limit")

        host.view.setFrameSize(NSSize(width: 200, height: 16))
        host.view.layoutSubtreeIfNeeded()
        #expect(host.view.maskRenderCount == 5, "new size")
    }

    @Test("The mask keeps to the line limit: one line, two lines, or every line when the limit is zero")
    func maskHonorsTheLineLimit() throws {
        let environment = FakeEnvironment()
        let view = TitleEffectView(environment: environment)
        view.frame = NSRect(x: 0, y: 0, width: 90, height: 120)
        let host = TitleHost(environment: environment, view: view)
        defer { host.close() }
        let long = "A long workspace name that wraps over several lines in the sidebar"
        let lineHeight = NSLayoutManager().defaultLineHeight(for: NSFont.systemFont(ofSize: 12))

        var inkRows: [Int: ClosedRange<CGFloat>] = [:]
        for limit in [1, 2, 0] {
            view.configure(text: title(long, size: 12), maximumNumberOfLines: limit, kind: .working, style: style)
            let rows = try #require(try inkRowRange(of: view), "limit \(limit) drew no ink")
            inkRows[limit] = rows
        }

        let one = try #require(inkRows[1])
        let two = try #require(inkRows[2])
        let unlimited = try #require(inkRows[0])
        #expect(one.upperBound <= lineHeight, "one line ends within the first line: \(one)")
        #expect(two.upperBound > lineHeight && two.upperBound <= 2 * lineHeight, "two lines: \(two)")
        #expect(unlimited.upperBound > 2 * lineHeight, "no limit draws every line: \(unlimited)")
    }

    @Test("A long single line is cut with an ellipsis inside the view")
    func singleLineIsTruncatedInsideTheView() throws {
        let environment = FakeEnvironment()
        let view = TitleEffectView(environment: environment)
        view.frame = NSRect(x: 0, y: 0, width: 80, height: 16)
        let host = TitleHost(environment: environment, view: view)
        defer { host.close() }

        view.configure(
            text: title("Terminal session that is far too long"),
            maximumNumberOfLines: 1,
            kind: .working,
            style: style
        )
        let truncated = try #require(try inkColumnRange(of: view))
        view.configure(text: title("Term"), maximumNumberOfLines: 1, kind: .working, style: style)
        let short = try #require(try inkColumnRange(of: view))

        #expect(truncated.upperBound <= 80, "the ink stays inside the view: \(truncated)")
        #expect(truncated.upperBound > 70, "the ellipsis ends near the right edge: \(truncated)")
        #expect(short.upperBound < 40, "a short title ends where its text ends: \(short)")
    }

    @Test(
        "One line is cut exactly where SwiftUI cuts a one-line Text of the same width",
        arguments: [
            ("Terminal session that is far too long", CGFloat(90), NSFont.Weight.semibold),
            ("Terminal session that is far too long", CGFloat(77), NSFont.Weight.regular),
            ("abcdefghijklmnopqrstuvwxyz", CGFloat(61), NSFont.Weight.regular),
            ("Terminal session", CGFloat(120), NSFont.Weight.regular)
        ]
    )
    func singleLineMaskMatchesSwiftUIText(title: String, width: CGFloat, weight: NSFont.Weight) throws {
        let font = NSFont.systemFont(ofSize: 11, weight: weight)
        let height: CGFloat = 16
        let text = SwiftUI.Text(title)
            .font(.system(size: 11, weight: weight == .semibold ? .semibold : .regular))
            .lineLimit(1)
            .foregroundStyle(SwiftUI.Color.white)
            .frame(width: width, height: height, alignment: .topLeading)
            .background(SwiftUI.Color.black)
        let hosting = NSHostingView(rootView: text)
        hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)
        let window = Self.makeWindow()
        defer { window.orderOut(nil) }
        window.contentView?.addSubview(hosting)
        for _ in 0..<5 {
            hosting.layoutSubtreeIfNeeded()
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
        let rendered = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        hosting.cacheDisplay(in: hosting.bounds, to: rendered)
        let scale = CGFloat(rendered.pixelsWide) / width

        let mask = try #require(
            TitleEffectTextMask(text: NSAttributedString(string: title, attributes: [.font: font]), maximumNumberOfLines: 1)
                .image(size: CGSize(width: width, height: height), scale: scale)
        )
        let maskRep = NSBitmapImageRep(cgImage: mask)

        let swiftUIInk = try #require(inkColumns(rendered) { color in
            var white: CGFloat = 0
            color.usingColorSpace(.deviceGray)?.getWhite(&white, alpha: nil)
            return white > 0.3
        })
        let maskInk = try #require(inkColumns(maskRep) { $0.alphaComponent > 0.3 })
        #expect(abs(swiftUIInk.lowerBound - maskInk.lowerBound) <= 1, "\(title) at \(width): left \(swiftUIInk) vs \(maskInk)")
        #expect(abs(swiftUIInk.upperBound - maskInk.upperBound) <= 1, "\(title) at \(width): right \(swiftUIInk) vs \(maskInk)")
    }

    // MARK: - Activity glyph

    @Test("The glyph cycles through six frames, one per frame duration")
    func glyphCyclesSixFrames() throws {
        let environment = FakeEnvironment()
        let host = GlyphHost(environment: environment)
        defer { host.close() }

        host.view.configure(kind: .working, style: style, pointSize: 12)

        let animation = try #require(
            host.view.glyphLayer.animation(forKey: ActivityGlyphView.cycleAnimationKey) as? CAKeyframeAnimation
        )
        #expect(animation.keyPath == "contents")
        #expect(animation.values?.count == 6)
        #expect(animation.calculationMode == .discrete)
        #expect(abs(animation.duration - 6 * style.glyphFrameDuration) < 0.001)
        #expect(animation.repeatCount == .infinity)
    }

    @Test("A working glyph is drawn in the working color; a highlighted glyph takes each stop in turn")
    func glyphFramesFollowTheColors() throws {
        let probe = TitleEffectStyle(
            workingBaseHex: "#B39550",
            workingHighlightHex: "#FFF3CF",
            glyphWorkingHex: "#00FF00",
            flashHex: "#D6C4FF42",
            highlightStopHexes: ["#FF0000", "#00FF00", "#0000FF", "#FFFF00", "#00FFFF", "#FF00FF", "#FF0000"]
        )
        let environment = FakeEnvironment()
        let host = GlyphHost(environment: environment)
        defer { host.close() }

        host.view.configure(kind: .working, style: probe, pointSize: 16)
        let working = try frameColorNames(of: host.view)
        #expect(working == Array(repeating: "green", count: 6), "working frames: \(working)")

        host.view.configure(kind: .highlight, style: probe, pointSize: 16)
        let highlight = try frameColorNames(of: host.view)
        #expect(highlight == ["red", "green", "blue", "yellow", "cyan", "magenta"], "highlight frames: \(highlight)")
    }

    @Test("Glyph frames are drawn in sRGB, like the title's colors, so they match on any display")
    func glyphFramesAreSRGB() throws {
        let host = GlyphHost(environment: FakeEnvironment())
        defer { host.close() }
        host.view.configure(kind: .working, style: style, pointSize: 16)

        let star = try #require(host.view.glyphLayer.contents.map { $0 as! CGImage })
        #expect(star.colorSpace?.name == CGColorSpace.sRGB, "frame color space: \(String(describing: star.colorSpace))")

        // The raw bytes of a fully covered pixel are the running color's sRGB components. (Reading the
        // pixel through `NSBitmapImageRep.colorAt` would label it Generic RGB and shift it.)
        let bytes = try #require(star.dataProvider?.data as Data?)
        let bytesPerPixel = star.bitsPerPixel / 8
        var solid: [UInt8]?
        for y in 0..<star.height where solid == nil {
            for x in 0..<star.width {
                let offset = y * star.bytesPerRow + x * bytesPerPixel
                if bytes[offset + 3] == 255 {
                    solid = Array(bytes[offset..<offset + 3])
                    break
                }
            }
        }
        let rgb = try #require(solid, "the ✻ frame has fully covered pixels")
        #expect(zip(rgb, [0xE8, 0xC4, 0x68] as [Int]).allSatisfy { abs(Int($0) - $1) <= 1 }, "pixel \(rgb), expected E8 C4 68")
    }

    @Test("A still glyph rests on ✻ and pauses with Reduce Motion or when it cannot be seen")
    func glyphRestsOnTheStarWhenStill() throws {
        let environment = FakeEnvironment()
        let host = GlyphHost(environment: environment)
        defer { host.close() }
        host.view.configure(kind: .working, style: style, pointSize: 14)
        let animation = try #require(
            host.view.glyphLayer.animation(forKey: ActivityGlyphView.cycleAnimationKey) as? CAKeyframeAnimation
        )
        let frames = try #require(animation.values?.map { $0 as! CGImage })
        let star = frames[4]

        environment.reducesMotion = true
        Self.announceDisplayOptionsChange()
        #expect(animationKeys(host.view.glyphLayer).isEmpty)
        let still = try #require(host.view.glyphLayer.contents.map { $0 as! CGImage })
        #expect(pixels(of: still) == pixels(of: star), "the still glyph is the ✻ frame")

        environment.reducesMotion = false
        Self.announceDisplayOptionsChange()
        #expect(animationKeys(host.view.glyphLayer) == [ActivityGlyphView.cycleAnimationKey])

        environment.visible = false
        host.announceOcclusionChange()
        #expect(animationKeys(host.view.glyphLayer).isEmpty)

        host.view.isPresentationActive = false
        environment.visible = true
        host.announceOcclusionChange()
        #expect(animationKeys(host.view.glyphLayer).isEmpty, "an inactive presentation stays still")
    }

    // MARK: - System environment

    @Test("The system environment calls a view visible only when it is shown in a window, and reads Reduce Motion from the workspace")
    func systemEnvironmentNeedsAShownViewInAWindow() {
        let environment = SystemTitleEffectEnvironment()
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 10, height: 10))
        #expect(!environment.isVisible(view), "a view without a window is not visible")

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 40, height: 40), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView?.addSubview(view)
        defer { window.orderOut(nil) }
        view.isHidden = true
        #expect(!environment.isVisible(view), "a hidden view is not visible")
        view.isHidden = false
        window.contentView?.isHidden = true
        #expect(!environment.isVisible(view), "a view with a hidden ancestor is not visible")
        window.contentView?.isHidden = false
        #expect(environment.isVisible(view) == window.occlusionState.contains(.visible))

        #expect(environment.reducesMotion == NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    }

    // MARK: - Helpers

    /// A title effect view in a window.
    @MainActor
    private struct TitleHost {
        let view: TitleEffectView
        let window: NSWindow

        init(environment: any TitleEffectEnvironment, view: TitleEffectView? = nil) {
            let view = view ?? {
                let created = TitleEffectView(environment: environment)
                created.frame = NSRect(x: 0, y: 0, width: 160, height: 16)
                return created
            }()
            self.view = view
            window = TitleEffectViewTests.makeWindow()
            window.contentView?.addSubview(view)
            view.layoutSubtreeIfNeeded()
        }

        func announceOcclusionChange() {
            NotificationCenter.default.post(name: NSWindow.didChangeOcclusionStateNotification, object: window)
        }

        func close() {
            window.orderOut(nil)
        }
    }

    /// An activity glyph view in a window.
    @MainActor
    private struct GlyphHost {
        let view: ActivityGlyphView
        let window: NSWindow

        init(environment: any TitleEffectEnvironment) {
            view = ActivityGlyphView(environment: environment)
            view.frame = NSRect(x: 0, y: 0, width: 20, height: 20)
            window = TitleEffectViewTests.makeWindow()
            window.contentView?.addSubview(view)
            view.layoutSubtreeIfNeeded()
        }

        func announceOcclusionChange() {
            NotificationCenter.default.post(name: NSWindow.didChangeOcclusionStateNotification, object: window)
        }

        func close() {
            window.orderOut(nil)
        }
    }

    /// An activity flash view in a window.
    @MainActor
    private struct FlashHost {
        let view: ActivityFlashView
        let window: NSWindow

        init(environment: any TitleEffectEnvironment, view: ActivityFlashView? = nil) {
            let view = view ?? {
                let created = ActivityFlashView(environment: environment)
                created.frame = NSRect(x: 0, y: 0, width: 160, height: 30)
                return created
            }()
            self.view = view
            window = TitleEffectViewTests.makeWindow()
            window.contentView?.addSubview(view)
            view.layoutSubtreeIfNeeded()
        }

        func announceOcclusionChange() {
            NotificationCenter.default.post(name: NSWindow.didChangeOcclusionStateNotification, object: window)
        }

        func close() {
            window.orderOut(nil)
        }
    }

    private static func makeWindow() -> NSWindow {
        _ = NSApplication.shared
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 160),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        return window
    }

    private static func announceDisplayOptionsChange() {
        NSWorkspace.shared.notificationCenter.post(
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: NSWorkspace.shared
        )
    }

    /// Where the gradient's start point travels during `animation`, in unit coordinates.
    private static func startPointTravel(of animation: CAAnimation) -> (from: CGFloat, to: CGFloat)? {
        let parts = (animation as? CAAnimationGroup)?.animations ?? [animation]
        for part in parts {
            guard let basic = part as? CABasicAnimation, basic.keyPath == "startPoint",
                  let from = (basic.fromValue as? NSValue)?.pointValue,
                  let to = (basic.toValue as? NSValue)?.pointValue else { continue }
            return (from.x, to.x)
        }
        return nil
    }

    private func title(_ string: String, size: CGFloat = 11, weight: NSFont.Weight = .regular) -> NSAttributedString {
        NSAttributedString(string: string, attributes: [.font: NSFont.systemFont(ofSize: size, weight: weight)])
    }

    private func animationKeys(_ layer: CALayer) -> [String] {
        layer.animationKeys() ?? []
    }

    /// The mask image's opaque pixels, read from the bitmap.
    private func maskBitmap(of view: TitleEffectView) throws -> (rep: NSBitmapImageRep, scale: CGFloat) {
        let image = try #require(view.textMaskLayer.contents.map { $0 as! CGImage })
        let rep = NSBitmapImageRep(cgImage: image)
        return (rep, CGFloat(rep.pixelsWide) / view.bounds.width)
    }

    private func inkCount(of view: TitleEffectView) throws -> Int {
        let (rep, _) = try maskBitmap(of: view)
        var count = 0
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide where alpha(rep, x, y) > 0.5 {
                count += 1
            }
        }
        return count
    }

    /// The top and bottom of the mask's ink, in points from the top of the view.
    private func inkRowRange(of view: TitleEffectView) throws -> ClosedRange<CGFloat>? {
        let (rep, scale) = try maskBitmap(of: view)
        var rows: [Int] = []
        for y in 0..<rep.pixelsHigh where (0..<rep.pixelsWide).contains(where: { alpha(rep, $0, y) > 0.3 }) {
            rows.append(y)
        }
        guard let first = rows.first, let last = rows.last else { return nil }
        return CGFloat(first) / scale...CGFloat(last + 1) / scale
    }

    /// The left and right of the mask's ink, in points from the left of the view.
    private func inkColumnRange(of view: TitleEffectView) throws -> ClosedRange<CGFloat>? {
        let (rep, scale) = try maskBitmap(of: view)
        var columns: [Int] = []
        for x in 0..<rep.pixelsWide where (0..<rep.pixelsHigh).contains(where: { alpha(rep, x, $0) > 0.3 }) {
            columns.append(x)
        }
        guard let first = columns.first, let last = columns.last else { return nil }
        return CGFloat(first) / scale...CGFloat(last + 1) / scale
    }

    /// The first and last pixel columns of `rep` holding a pixel that counts as ink.
    private func inkColumns(_ rep: NSBitmapImageRep, isInk: (NSColor) -> Bool) -> ClosedRange<Int>? {
        var columns: [Int] = []
        for x in 0..<rep.pixelsWide where (0..<rep.pixelsHigh).contains(where: { rep.colorAt(x: x, y: $0).map(isInk) ?? false }) {
            columns.append(x)
        }
        guard let first = columns.first, let last = columns.last else { return nil }
        return first...last
    }

    private func alpha(_ rep: NSBitmapImageRep, _ x: Int, _ y: Int) -> CGFloat {
        rep.colorAt(x: x, y: y)?.alphaComponent ?? 0
    }

    /// The probe color name of each frame of the glyph's running animation.
    private func frameColorNames(of view: ActivityGlyphView) throws -> [String] {
        let animation = try #require(
            view.glyphLayer.animation(forKey: ActivityGlyphView.cycleAnimationKey) as? CAKeyframeAnimation
        )
        let frames = try #require(animation.values?.map { $0 as! CGImage })
        return frames.map { dominantColorName(of: $0) }
    }

    /// Names the probe color of an image's solid pixels, counting a channel as on above 0.75.
    private func dominantColorName(of image: CGImage) -> String {
        let rep = NSBitmapImageRep(cgImage: image)
        var counts: [String: Int] = [:]
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide {
                guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB), color.alphaComponent > 0.9 else { continue }
                let on = [color.redComponent, color.greenComponent, color.blueComponent].map { $0 > 0.75 }
                let name: String
                switch (on[0], on[1], on[2]) {
                case (true, false, false): name = "red"
                case (false, true, false): name = "green"
                case (false, false, true): name = "blue"
                case (true, true, false): name = "yellow"
                case (false, true, true): name = "cyan"
                case (true, false, true): name = "magenta"
                default: name = "other"
                }
                counts[name, default: 0] += 1
            }
        }
        return counts.max { $0.value < $1.value }?.key ?? "empty"
    }

    private func pixels(of image: CGImage) -> Data? {
        NSBitmapImageRep(cgImage: image).tiffRepresentation
    }

    /// Whether `color` is within `tolerance` of the sRGB color `hex`, per channel.
    private func isClose(_ color: CGColor, toHex hex: UInt32, tolerance: CGFloat = 0.01) -> Bool {
        guard let srgb = CGColorSpace(name: CGColorSpace.sRGB),
              let converted = color.converted(to: srgb, intent: .defaultIntent, options: nil),
              let components = converted.components, components.count >= 3 else { return false }
        let expected: [CGFloat] = [
            CGFloat((hex >> 16) & 0xFF) / 255,
            CGFloat((hex >> 8) & 0xFF) / 255,
            CGFloat(hex & 0xFF) / 255
        ]
        return zip(components.prefix(3), expected).allSatisfy { abs($0 - $1) <= tolerance }
    }
}

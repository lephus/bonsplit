import AppKit
import QuartzCore

/// The glyph that shows a coding agent is active: `· ✢ ✳ ✶ ✻ ✽` cycling the way Claude Code cycles them.
///
/// A working glyph is drawn in the style's working color; a highlighted glyph takes the highlight
/// colors in turn, one per frame. The frames are drawn once per configuration and cycled by a
/// discrete Core Animation keyframe animation on the render server, so the main thread does no
/// per-frame work. The view cycles only while ``isPresentationActive`` is true and its
/// ``TitleEffectEnvironment`` says it can be seen and motion is allowed; otherwise it rests on ✻.
/// The glyph is centered in the view. The view is decorative: it takes no clicks and is not an
/// accessibility element.
///
/// ```swift
/// let glyph = ActivityGlyphView()
/// glyph.frame = iconSlotFrame
/// glyph.configure(kind: .working, style: style, pointSize: 12)
/// ```
public final class ActivityGlyphView: NSView {
    /// Key of the frame cycle on ``glyphLayer``.
    static let cycleAnimationKey = "activityGlyph.cycle"

    /// The layer showing the current frame.
    let glyphLayer = CALayer()

    /// Whether the glyph may cycle: hosts turn it off for rows that are scrolled away or not presented.
    ///
    /// An inactive view rests on ✻.
    public var isPresentationActive = true {
        didSet {
            guard isPresentationActive != oldValue else { return }
            updateAnimationState()
        }
    }

    private let environment: any TitleEffectEnvironment
    private var motionObserver: TitleEffectMotionObserver?
    private var configuration: Configuration?
    private var renderedFrames: RenderedFrames?
    private var frames: [CGImage] = []

    /// What the frames are drawn from.
    private struct Configuration: Equatable {
        let kind: TabActivity.Kind
        let style: TitleEffectStyle
        let pointSize: CGFloat
    }

    /// The frames last drawn, and what they were drawn for.
    private struct RenderedFrames: Equatable {
        let configuration: Configuration
        let scale: CGFloat
        let appearanceName: NSAppearance.Name
    }

    /// Creates a glyph view with nothing to show until it is configured.
    ///
    /// - Parameter environment: Where the view learns whether it can be seen and whether motion is allowed.
    ///   The system environment by default; tests pass their own.
    public init(environment: any TitleEffectEnvironment = SystemTitleEffectEnvironment()) {
        self.environment = environment
        super.init(frame: .zero)
        wantsLayer = true
        setAccessibilityElement(false)
        layer?.masksToBounds = false
        glyphLayer.contentsGravity = .center
        layer?.addSublayer(glyphLayer)
        motionObserver = TitleEffectMotionObserver { [weak self] in
            self?.updateAnimationState()
        }
    }

    /// Unavailable: the view is built in code.
    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        nil
    }

    /// Sets the glyph's colors and size.
    ///
    /// Calling it again with the same values does nothing, so hosts may call it on every update.
    ///
    /// - Parameters:
    ///   - kind: Working draws every frame in the working glyph color; highlight gives each frame the next highlight color.
    ///   - style: The colors and the frame duration.
    ///   - pointSize: The point size of the glyph font.
    public func configure(kind: TabActivity.Kind, style: TitleEffectStyle, pointSize: CGFloat) {
        let next = Configuration(kind: kind, style: style, pointSize: pointSize)
        guard next != configuration else { return }
        configuration = next
        // New frames or timing: the cycle is added again below.
        glyphLayer.removeAnimation(forKey: Self.cycleAnimationKey)
        renderFramesIfNeeded()
        updateAnimationState()
    }

    // MARK: - NSView

    /// Fits the glyph layer to the new size.
    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        sizeDidChange()
    }

    /// Fits the glyph layer to the laid-out size.
    public override func layout() {
        super.layout()
        sizeDidChange()
    }

    /// Fits the glyph layer to a new size and decides again whether to cycle.
    private func sizeDidChange() {
        guard glyphLayer.frame != bounds else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        glyphLayer.frame = bounds
        CATransaction.commit()
        updateAnimationState()
    }

    /// Follows the new window's occlusion and decides again whether to move.
    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        motionObserver?.observeOcclusion(of: window)
        renderFramesIfNeeded()
        updateAnimationState()
    }

    /// Stops moving while the view or an ancestor is hidden.
    public override func viewDidHide() {
        super.viewDidHide()
        updateAnimationState()
    }

    /// Moves again, if it may, once the view is shown.
    public override func viewDidUnhide() {
        super.viewDidUnhide()
        updateAnimationState()
    }

    /// Draws the frames again for the new screen scale.
    public override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        if renderFramesIfNeeded() {
            updateAnimationState()
        }
    }

    /// Draws the frames again for the new appearance.
    public override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        if renderFramesIfNeeded() {
            updateAnimationState()
        }
    }

    /// The glyph is decorative; clicks go to the view under it.
    public override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    // MARK: - Frames

    /// Draws the frames when the configuration, the scale or the appearance changed; returns whether it drew.
    @discardableResult
    private func renderFramesIfNeeded() -> Bool {
        guard let configuration else { return false }
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        let rendered = RenderedFrames(configuration: configuration, scale: scale, appearanceName: effectiveAppearance.name)
        guard rendered != renderedFrames else { return false }
        renderedFrames = rendered
        let colors = TitleEffectColors(style: configuration.style, appearance: effectiveAppearance)
            .glyphFrameColors(for: configuration.kind, frameCount: ActivityGlyphFrames.glyphs.count)
        frames = ActivityGlyphFrames(pointSize: configuration.pointSize).images(colors: colors, scale: scale)
        glyphLayer.removeAnimation(forKey: Self.cycleAnimationKey)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        glyphLayer.contents = frames.indices.contains(ActivityGlyphFrames.stillFrameIndex)
            ? frames[ActivityGlyphFrames.stillFrameIndex]
            : nil
        glyphLayer.contentsScale = scale
        CATransaction.commit()
        return true
    }

    /// Whether the glyph may cycle now.
    private var canAnimate: Bool {
        guard isPresentationActive, configuration != nil, window != nil, !bounds.isEmpty else { return false }
        guard environment.isVisible(self) else { return false }
        return !environment.reducesMotion
    }

    /// Adds the cycle when the glyph may move and removes it when it may not; the layer itself always holds ✻.
    private func updateAnimationState() {
        guard canAnimate, let configuration, frames.count == ActivityGlyphFrames.glyphs.count else {
            glyphLayer.removeAnimation(forKey: Self.cycleAnimationKey)
            return
        }
        guard glyphLayer.animation(forKey: Self.cycleAnimationKey) == nil else { return }
        let frameDuration = max(0.01, configuration.style.glyphFrameDuration)
        let cycle = CAKeyframeAnimation(keyPath: "contents")
        cycle.values = frames
        cycle.keyTimes = (0...frames.count).map { NSNumber(value: Double($0) / Double(frames.count)) }
        cycle.calculationMode = .discrete
        cycle.duration = frameDuration * Double(frames.count)
        cycle.repeatCount = .infinity
        cycle.isRemovedOnCompletion = false
        cycle.beginTime = TitleEffectView.syncedBeginTime(for: glyphLayer, duration: cycle.duration)
        // The glyph changes a few times a second; asking for more frames would only cost the window server.
        let stepsPerSecond = Float(1 / frameDuration)
        cycle.preferredFrameRateRange = CAFrameRateRange(
            minimum: stepsPerSecond,
            maximum: stepsPerSecond * 2,
            preferred: stepsPerSecond * 2
        )
        glyphLayer.add(cycle, forKey: Self.cycleAnimationKey)
    }
}

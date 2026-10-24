import AppKit
import QuartzCore

/// A title drawn in moving color while a coding agent works: a highlight sweeping across gold text,
/// or pastel colors flowing while a skill or workflow runs.
///
/// The view draws the text itself, as a mask over a `CAGradientLayer`, so the real title under it
/// keeps the layout and the accessibility text and only turns its own color clear. Lay the view
/// exactly over the title's text: the text starts at the view's top-left corner with no padding.
/// One line is cut at the tail like SwiftUI's `Text`; more lines wrap at words like a wrapping
/// `NSTextField` and the last allowed line is cut at the tail. The view is decorative: it takes no
/// clicks and is not an accessibility element. The one-time flash when a skill or workflow starts
/// covers the whole tab or row, so it is a separate view, ``ActivityFlashView``.
///
/// Everything moves on the render server through Core Animation; the main thread only draws the
/// text mask again when the text, its font, the view's size or the line limit change. The view
/// moves only while ``isPresentationActive`` is true and its ``TitleEffectEnvironment`` says it
/// can be seen and motion is allowed. Otherwise it holds a still look: a working title in the
/// running color (``TitleEffectStyle/glyphWorkingHex``) and a highlighted title in a still pastel
/// gradient. Moving or still, a short highlighted title shows every color of the loop across its
/// text at once, and a long one half of the loop.
///
/// ```swift
/// let effect = TitleEffectView()
/// effect.frame = titleTextFrame
/// effect.configure(
///     text: NSAttributedString(string: "claude", attributes: [.font: NSFont.systemFont(ofSize: 11)]),
///     maximumNumberOfLines: 1,
///     kind: .working,
///     style: style
/// )
/// ```
public final class TitleEffectView: NSView {
    /// Key of the working sweep on ``gradientLayer``.
    static let sweepAnimationKey = "titleEffect.sweep"

    /// Key of the highlight's color flow on ``gradientLayer``.
    static let flowAnimationKey = "titleEffect.flow"

    /// The colored text: a gradient masked by ``textMaskLayer``.
    let gradientLayer = CAGradientLayer()

    /// The text as an alpha mask.
    let textMaskLayer = CALayer()

    /// Times the text mask was drawn so far.
    private(set) var maskRenderCount = 0

    /// Whether the effect may move: hosts turn it off for titles that are scrolled away or not presented.
    ///
    /// An inactive view holds its still look.
    public var isPresentationActive = true {
        didSet {
            guard isPresentationActive != oldValue else { return }
            updateAnimationState()
        }
    }

    private let environment: any TitleEffectEnvironment
    private var motionObserver: TitleEffectMotionObserver?
    private var mask: TitleEffectTextMask?
    private var renderedMask: RenderedMask?
    private var kind: TabActivity.Kind?
    private var style: TitleEffectStyle?
    private var colors: TitleEffectColors?
    private var laidOutSize: CGSize?
    /// Width of the text as the mask last drew it; nil before the first mask.
    private var textWidth: CGFloat?
    /// The gradient span the flow on the layer was made for.
    private var flowSpanInUse: CGFloat?

    /// The mask image last drawn, and what it was drawn for.
    private struct RenderedMask: Equatable {
        let mask: TitleEffectTextMask
        let size: CGSize
        let scale: CGFloat
    }

    /// The working gradient spans 2.5 widths, the base color with the highlight in its middle; the
    /// sweep slides it 1.5 widths to the right.
    private static let sweepSpan: CGFloat = 2.5
    private static let sweepStartX: CGFloat = -1.5

    /// The highlight gradient holds the color loop twice, and the flow slides it one loop to the
    /// right so it starts over where it began. A long title's loop is two view widths, so the
    /// gradient spans four; a short title's is shorter (``highlightLoopLength(textWidth:viewWidth:)``).
    private static let longFlowSpan: CGFloat = 4

    /// Text at most this many points wide shows the whole highlight loop across it at once.
    static let fullLoopTextWidth: CGFloat = 80

    /// Text at least this many points wide keeps a loop of two view widths.
    static let wideLoopTextWidth: CGFloat = 160

    /// The length, in points, of one highlight loop over text `textWidth` points wide in a view
    /// `viewWidth` points wide.
    ///
    /// Text up to ``fullLoopTextWidth`` gets a loop as long as itself, so all of its colors show at
    /// once and no single one, such as the gold, can pass for the working yellow. Text from
    /// ``wideLoopTextWidth`` on keeps two view widths. In between, the length moves linearly from
    /// one to the other, so a title that grows by a letter does not jump.
    static func highlightLoopLength(textWidth: CGFloat, viewWidth: CGFloat) -> CGFloat {
        let long = 2 * viewWidth
        guard textWidth > 0, textWidth < wideLoopTextWidth else { return long }
        let blend = max(0, textWidth - fullLoopTextWidth) / (wideLoopTextWidth - fullLoopTextWidth)
        return textWidth + (long - textWidth) * blend
    }

    /// Creates an effect view with nothing to show until it is configured.
    ///
    /// - Parameter environment: Where the view learns whether it can be seen and whether motion is allowed.
    ///   The system environment by default; tests pass their own.
    public init(environment: any TitleEffectEnvironment = SystemTitleEffectEnvironment()) {
        self.environment = environment
        super.init(frame: .zero)
        wantsLayer = true
        setAccessibilityElement(false)
        setUpLayers()
        motionObserver = TitleEffectMotionObserver { [weak self] in
            self?.updateAnimationState()
        }
    }

    /// Unavailable: the view is built in code.
    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        nil
    }

    /// Sets the text and the effect to draw.
    ///
    /// Calling it again with the same values does nothing, so hosts may call it on every update.
    ///
    /// - Parameters:
    ///   - text: The title with its fonts, as the real title draws it. Its colors are ignored.
    ///   - maximumNumberOfLines: The title's line limit: `1` for one line cut at the tail, more to wrap
    ///     at words, `0` for no limit.
    ///   - kind: The effect, or nil to hide it.
    ///   - style: The colors and timing.
    public func configure(
        text: NSAttributedString,
        maximumNumberOfLines: Int,
        kind: TabActivity.Kind?,
        style: TitleEffectStyle
    ) {
        let textChanged = mask.map { !$0.text.isEqual(to: text) || $0.maximumNumberOfLines != maximumNumberOfLines } ?? true
        if textChanged {
            mask = TitleEffectTextMask(
                text: NSAttributedString(attributedString: text),
                maximumNumberOfLines: maximumNumberOfLines
            )
        }
        let styleChanged = self.style != style
        if styleChanged {
            self.style = style
            colors = nil
            // The timing may have changed: the animations are added again below.
            removeEffectAnimations()
        }
        let kindChanged = self.kind != kind
        self.kind = kind
        guard textChanged || styleChanged || kindChanged else { return }
        renderMaskIfNeeded()
        updateAnimationState()
    }

    // MARK: - NSView

    /// Fits the layers and the mask to the new size.
    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        sizeDidChange()
    }

    /// Fits the layers and the mask to the laid-out size.
    public override func layout() {
        super.layout()
        sizeDidChange()
    }

    /// Follows the new window's occlusion and decides again whether to move.
    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        motionObserver?.observeOcclusion(of: window)
        renderMaskIfNeeded()
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

    /// Draws the mask again for the new screen scale.
    public override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        renderMaskIfNeeded()
    }

    /// Resolves the colors again for the new appearance.
    public override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        colors = nil
        updateAnimationState()
    }

    /// The effect is decorative; clicks go to the title under it.
    public override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    // MARK: - Layers

    private func setUpLayers() {
        guard let layer else { return }
        layer.masksToBounds = false
        gradientLayer.mask = textMaskLayer
        gradientLayer.isHidden = true
        layer.addSublayer(gradientLayer)
    }

    /// Fits the layers to a new size, draws the mask for it and decides again whether to move.
    private func sizeDidChange() {
        guard bounds.size != laidOutSize else { return }
        laidOutSize = bounds.size
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradientLayer.frame = bounds
        textMaskLayer.frame = gradientLayer.bounds
        CATransaction.commit()
        renderMaskIfNeeded()
        updateAnimationState()
    }

    private var backingScale: CGFloat {
        window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
    }

    /// Draws the text mask when the text, its font, the line limit, the size or the scale changed since it was last drawn.
    private func renderMaskIfNeeded() {
        guard kind != nil, let mask, !bounds.isEmpty else { return }
        let rendered = RenderedMask(mask: mask, size: bounds.size, scale: backingScale)
        guard rendered != renderedMask else { return }
        renderedMask = rendered
        maskRenderCount += 1
        let image = mask.image(size: rendered.size, scale: rendered.scale)
        textWidth = mask.textWidth(width: rendered.size.width)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        textMaskLayer.contents = image
        textMaskLayer.contentsScale = rendered.scale
        CATransaction.commit()
    }

    /// The highlight gradient's span in units of the view's width: two loops.
    private var highlightSpan: CGFloat {
        guard let textWidth, bounds.width > 0 else { return Self.longFlowSpan }
        return 2 * Self.highlightLoopLength(textWidth: textWidth, viewWidth: bounds.width) / bounds.width
    }

    private var resolvedColors: TitleEffectColors? {
        if let colors { return colors }
        guard let style else { return nil }
        let resolved = TitleEffectColors(style: style, appearance: effectiveAppearance)
        colors = resolved
        return resolved
    }

    /// Whether the effect may move now.
    private var canAnimate: Bool {
        guard isPresentationActive, kind != nil, window != nil, !bounds.isEmpty else { return false }
        guard environment.isVisible(self) else { return false }
        return !environment.reducesMotion
    }

    /// Shows the still or the moving look and adds or removes the animations to match.
    private func updateAnimationState() {
        let animates = canAnimate
        applyLayerValues(animating: animates)
        guard animates, let kind, let style else {
            removeEffectAnimations()
            return
        }
        switch kind {
        case .working:
            gradientLayer.removeAnimation(forKey: Self.flowAnimationKey)
            if gradientLayer.animation(forKey: Self.sweepAnimationKey) == nil {
                gradientLayer.add(
                    makeTravel(startX: Self.sweepStartX, span: Self.sweepSpan, duration: style.workingSweepDuration),
                    forKey: Self.sweepAnimationKey
                )
            }
        case .highlight:
            gradientLayer.removeAnimation(forKey: Self.sweepAnimationKey)
            let span = highlightSpan
            if span != flowSpanInUse {
                // The text or the size gave the loop a new length: the flow starts over with it.
                gradientLayer.removeAnimation(forKey: Self.flowAnimationKey)
            }
            if gradientLayer.animation(forKey: Self.flowAnimationKey) == nil {
                gradientLayer.add(
                    makeTravel(startX: -span / 2, span: span, duration: style.highlightCycleDuration),
                    forKey: Self.flowAnimationKey
                )
                flowSpanInUse = span
            }
        }
    }

    /// The layer values under the animations: the still look, or the gradient the sweep slides.
    private func applyLayerValues(animating: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        guard let kind, let colors = resolvedColors else {
            gradientLayer.isHidden = true
            return
        }
        gradientLayer.isHidden = false
        switch kind {
        case .working:
            if animating {
                let base = colors.workingBase
                gradientLayer.colors = [base, base, colors.workingHighlight, base, base]
                gradientLayer.locations = [0, 0.38, 0.5, 0.62, 1]
                gradientLayer.startPoint = CGPoint(x: Self.sweepStartX, y: 0.5)
                gradientLayer.endPoint = CGPoint(x: Self.sweepStartX + Self.sweepSpan, y: 0.5)
            } else {
                // A working title that holds still is drawn in the running color, the glyph's.
                gradientLayer.colors = [colors.glyphWorking, colors.glyphWorking]
                gradientLayer.locations = nil
                gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
                gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
            }
        case .highlight:
            // Still or moving, the title starts on the first loop, at the same length.
            gradientLayer.colors = colors.highlightGradient
            gradientLayer.locations = nil
            gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
            gradientLayer.endPoint = CGPoint(x: highlightSpan, y: 0.5)
        }
    }

    private func removeEffectAnimations() {
        gradientLayer.removeAnimation(forKey: Self.sweepAnimationKey)
        gradientLayer.removeAnimation(forKey: Self.flowAnimationKey)
    }

    /// Slides the gradient one step to the right forever: its start point from `startX` to `0`, its
    /// end point `span` further, at a constant speed.
    private func makeTravel(startX: CGFloat, span: CGFloat, duration: Double) -> CAAnimation {
        let seconds = max(0.01, duration)
        let start = CABasicAnimation(keyPath: "startPoint")
        start.fromValue = NSValue(point: CGPoint(x: startX, y: 0.5))
        start.toValue = NSValue(point: CGPoint(x: 0, y: 0.5))
        start.duration = seconds
        let end = CABasicAnimation(keyPath: "endPoint")
        end.fromValue = NSValue(point: CGPoint(x: startX + span, y: 0.5))
        end.toValue = NSValue(point: CGPoint(x: span, y: 0.5))
        end.duration = seconds
        let travel = CAAnimationGroup()
        travel.animations = [start, end]
        travel.duration = seconds
        travel.repeatCount = .infinity
        travel.isRemovedOnCompletion = false
        travel.beginTime = Self.syncedBeginTime(for: gradientLayer, duration: seconds)
        // A smooth slide needs no more than 60 Hz, even on faster displays.
        travel.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        return travel
    }

    /// A begin time on the shared media clock, so every effect of the same duration moves in step.
    static func syncedBeginTime(for layer: CALayer, duration: CFTimeInterval) -> CFTimeInterval {
        let globalNow = CACurrentMediaTime()
        let layerNow = layer.convertTime(globalNow, from: nil)
        return layerNow - globalNow.truncatingRemainder(dividingBy: duration)
    }
}

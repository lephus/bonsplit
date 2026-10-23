import AppKit
import QuartzCore

/// A one-time wash over a whole tab or row when a coding agent starts a skill or a workflow.
///
/// Lay the view over the full tab or row, above its fill and below its content. When it is
/// configured with a ``TabActivity/Kind/highlight`` whose generation it has not shown yet, it fades
/// ``TitleEffectStyle/flashHex`` (alpha included) in over ``TitleEffectStyle/flashRiseDuration``
/// and out over ``TitleEffectStyle/flashFadeDuration``, once, as a Core Animation animation on
/// the render server. Between flashes it draws nothing.
///
/// It never flashes under Reduce Motion, while its ``TitleEffectEnvironment`` says it cannot be
/// seen, or while ``isPresentationActive`` is false: a flash that cannot play when its highlight
/// starts is dropped, not played later. A view that is not on screen and laid out yet keeps its
/// flash until it is. The view is decorative: it takes no clicks and is not an accessibility element.
///
/// ```swift
/// let flash = ActivityFlashView()
/// flash.frame = row.bounds
/// // Reusing the view for a row whose skill already flashed: say so before configuring.
/// flash.flashedGeneration = row.lastFlashedGeneration
/// flash.configure(kind: .highlight, generation: marker.generation, style: style)
/// ```
public final class ActivityFlashView: NSView {
    /// Key of the flash on ``flashLayer``.
    static let flashAnimationKey = "activityFlash.flash"

    /// The wash: fully transparent except while a flash plays.
    let flashLayer = CALayer()

    /// Flashes played so far.
    private(set) var flashCount = 0

    /// Highlight generations that asked for a flash so far, whether it could play or not.
    private(set) var flashRequestCount = 0

    /// The highlight generation this view already flashed for, or skipped; nil before its first highlight.
    ///
    /// ``configure(kind:generation:style:)`` flashes for a highlight whose generation differs from this
    /// value, then stores that generation here. A host that builds the view again, or reuses it, for
    /// content that already flashed sets this to that content's generation before configuring, so the
    /// same skill or workflow does not flash twice.
    public var flashedGeneration: UInt64?

    /// Whether the view may flash: hosts turn it off for rows that are scrolled away or not presented.
    ///
    /// Turning it off also stops a flash that is playing.
    public var isPresentationActive = true {
        didSet {
            guard isPresentationActive != oldValue else { return }
            updateFlashState()
        }
    }

    /// Corner radius of the wash, so it can follow a rounded row; `0`, square like a tab, by default.
    public var cornerRadius: CGFloat = 0 {
        didSet {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            flashLayer.cornerRadius = cornerRadius
            CATransaction.commit()
        }
    }

    private let environment: any TitleEffectEnvironment
    private var motionObserver: TitleEffectMotionObserver?
    private var style: TitleEffectStyle?
    private var isFlashPending = false

    /// Creates a flash view that shows nothing until a highlight starts.
    ///
    /// - Parameter environment: Where the view learns whether it can be seen and whether motion is allowed.
    ///   The system environment by default; tests pass their own.
    public init(environment: any TitleEffectEnvironment = SystemTitleEffectEnvironment()) {
        self.environment = environment
        super.init(frame: .zero)
        wantsLayer = true
        setAccessibilityElement(false)
        layer?.masksToBounds = false
        flashLayer.opacity = 0
        layer?.addSublayer(flashLayer)
        motionObserver = TitleEffectMotionObserver { [weak self] in
            self?.updateFlashState()
        }
    }

    /// Unavailable: the view is built in code.
    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        nil
    }

    /// Tells the view what the agent is doing; a highlight with a generation it has not shown flashes once.
    ///
    /// Calling it again with the same values does nothing, so hosts may call it on every update.
    ///
    /// - Parameters:
    ///   - kind: The agent's activity; only ``TabActivity/Kind/highlight`` flashes.
    ///   - generation: The highlight's generation, compared with ``flashedGeneration``.
    ///   - style: The flash color and timing.
    public func configure(kind: TabActivity.Kind?, generation: UInt64, style: TitleEffectStyle) {
        if style != self.style {
            self.style = style
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            flashLayer.backgroundColor = TitleEffectColors(style: style, appearance: effectiveAppearance).flash
            CATransaction.commit()
        }
        guard kind == .highlight else {
            isFlashPending = false
            return
        }
        guard generation != flashedGeneration else { return }
        flashedGeneration = generation
        flashRequestCount += 1
        isFlashPending = true
        updateFlashState()
    }

    // MARK: - NSView

    /// Fits the wash to the new size.
    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        sizeDidChange()
    }

    /// Fits the wash to the laid-out size.
    public override func layout() {
        super.layout()
        sizeDidChange()
    }

    /// Follows the new window's occlusion and plays a flash that was waiting for the window.
    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        motionObserver?.observeOcclusion(of: window)
        updateFlashState()
    }

    /// Stops a flash while the view or an ancestor is hidden.
    public override func viewDidHide() {
        super.viewDidHide()
        updateFlashState()
    }

    /// Decides again whether a waiting flash may play once the view is shown.
    public override func viewDidUnhide() {
        super.viewDidUnhide()
        updateFlashState()
    }

    /// The wash is decorative; clicks go to the tab or row under it.
    public override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    // MARK: - Flash

    private func sizeDidChange() {
        guard flashLayer.frame != bounds else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        flashLayer.frame = bounds
        CATransaction.commit()
        updateFlashState()
    }

    /// Whether a flash may play now.
    private var canFlash: Bool {
        guard isPresentationActive, style != nil, window != nil, !bounds.isEmpty else { return false }
        guard environment.isVisible(self) else { return false }
        return !environment.reducesMotion
    }

    /// Plays a waiting flash when it may; stops a playing one when the view can no longer move.
    private func updateFlashState() {
        let canFlash = canFlash
        if !canFlash {
            flashLayer.removeAnimation(forKey: Self.flashAnimationKey)
        }
        guard isFlashPending, let style else { return }
        if canFlash {
            isFlashPending = false
            flashLayer.add(makeFlash(style: style), forKey: Self.flashAnimationKey)
            flashCount += 1
        } else if window != nil, !bounds.isEmpty {
            // On screen but still: the flash belongs to the start of the highlight, so it is dropped.
            isFlashPending = false
        }
    }

    /// One beat of the wash: up to its color's full alpha, then back to nothing.
    private func makeFlash(style: TitleEffectStyle) -> CAAnimation {
        let rise = max(0, style.flashRiseDuration)
        let total = max(0.01, rise + max(0, style.flashFadeDuration))
        let flash = CAKeyframeAnimation(keyPath: "opacity")
        flash.values = [0, 1, 0]
        flash.keyTimes = [0, NSNumber(value: rise / total), 1]
        flash.timingFunctions = [CAMediaTimingFunction(name: .easeOut), CAMediaTimingFunction(name: .easeOut)]
        flash.duration = total
        flash.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        return flash
    }
}

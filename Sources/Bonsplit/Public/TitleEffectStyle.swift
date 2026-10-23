import Foundation

/// Colors and timing of the agent activity effects drawn by ``TitleEffectView``, ``ActivityGlyphView``
/// and ``ActivityFlashView``.
///
/// Hosts opt the pane tab bar in through ``BonsplitConfiguration/Appearance/titleEffectStyle``.
/// Every color is a hex string (`#RRGGBB` or `#RRGGBBAA`), read the same way as
/// ``BonsplitConfiguration/Appearance/ChromeColors``. A string that is not valid hex falls back:
/// the base color to the label color, the highlight and the glyph color to the base color, the
/// flash to no flash, and unreadable stops are skipped (no readable stop leaves the base color).
/// Durations are in seconds.
///
/// ```swift
/// let style = TitleEffectStyle(
///     workingBaseHex: "#b39550",
///     workingHighlightHex: "#fff3cf",
///     glyphWorkingHex: "#e8c468",
///     flashHex: "#d6c4ff42",
///     highlightStopHexes: ["#f4a7c0", "#f2c879", "#8fd9a8", "#7cc8e8", "#9fb0f5", "#c9a7f2", "#f4a7c0"]
/// )
/// ```
public struct TitleEffectStyle: Sendable, Equatable {
    /// Hex color of a working title while the highlight sweeps across it.
    public var workingBaseHex: String

    /// Hex color of the highlight that sweeps across a working title from left to right.
    public var workingHighlightHex: String

    /// Hex "running" color: the activity glyph while the agent is working, and a working title that
    /// holds still (Reduce Motion, or not visible).
    public var glyphWorkingHex: String

    /// Hex color of the one-time flash over the whole tab or row at its peak, alpha included (for
    /// example `#d6c4ff42` for 26%).
    public var flashHex: String

    /// Hex colors a highlighted title flows through from left to right, and the glyph takes one per frame.
    ///
    /// The colors form a loop: the effect closes it on the first color, so repeating that color at the
    /// end is allowed and gives the same result.
    public var highlightStopHexes: [String]

    /// Seconds the highlight takes to sweep once across a working title.
    public var workingSweepDuration: Double

    /// Seconds a highlighted title takes to flow through all its colors once.
    public var highlightCycleDuration: Double

    /// Seconds each of the glyph's six frames stays on screen.
    public var glyphFrameDuration: Double

    /// Seconds the flash takes to reach its peak.
    public var flashRiseDuration: Double

    /// Seconds the flash takes to fade out after its peak.
    public var flashFadeDuration: Double

    /// Creates a style from every color and duration; the durations default to the ShellX timing.
    ///
    /// - Parameters:
    ///   - workingBaseHex: Color of a working title.
    ///   - workingHighlightHex: Color of the highlight that sweeps across a working title.
    ///   - glyphWorkingHex: Color of the glyph while working.
    ///   - flashHex: Color of the flash at its peak, alpha included.
    ///   - highlightStopHexes: Colors a highlighted title flows through.
    ///   - workingSweepDuration: Seconds per sweep, 2.2 by default.
    ///   - highlightCycleDuration: Seconds per color cycle, 3.0 by default.
    ///   - glyphFrameDuration: Seconds per glyph frame, 0.18 by default.
    ///   - flashRiseDuration: Seconds the flash rises, 0.15 by default.
    ///   - flashFadeDuration: Seconds the flash fades, 0.8 by default.
    public init(
        workingBaseHex: String,
        workingHighlightHex: String,
        glyphWorkingHex: String,
        flashHex: String,
        highlightStopHexes: [String],
        workingSweepDuration: Double = 2.2,
        highlightCycleDuration: Double = 3.0,
        glyphFrameDuration: Double = 0.18,
        flashRiseDuration: Double = 0.15,
        flashFadeDuration: Double = 0.8
    ) {
        self.workingBaseHex = workingBaseHex
        self.workingHighlightHex = workingHighlightHex
        self.glyphWorkingHex = glyphWorkingHex
        self.flashHex = flashHex
        self.highlightStopHexes = highlightStopHexes
        self.workingSweepDuration = workingSweepDuration
        self.highlightCycleDuration = highlightCycleDuration
        self.glyphFrameDuration = glyphFrameDuration
        self.flashRiseDuration = flashRiseDuration
        self.flashFadeDuration = flashFadeDuration
    }
}

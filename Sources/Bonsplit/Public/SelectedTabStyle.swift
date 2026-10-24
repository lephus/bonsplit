import CoreGraphics

/// Colors and metrics that make the selected tab stand out: a tinted fill, a bold title and an indicator on the bottom edge.
///
/// Hosts opt in through ``BonsplitConfiguration/Appearance/selectedTabStyle``; without it Bonsplit
/// draws its default selected tab. Every color is a hex string (`#RRGGBB` or `#RRGGBBAA`), read the
/// same way as ``BonsplitConfiguration/Appearance/ChromeColors``. A string that is not valid hex
/// paints no fill, the label color for titles and the system accent color for the indicator.
///
/// The tab bar does not desaturate a styled selected tab, so the colors themselves carry the
/// focus state: the focused pane uses the accent colors and every other pane the unfocused ones.
public struct SelectedTabStyle: Sendable, Equatable {
    /// Hex fill of the selected tab in the focused pane while its window is key or main in the active app.
    public var fillHex: String

    /// Hex fill of the selected tab in the focused pane while the app is inactive.
    public var inactiveWindowFillHex: String

    /// Hex fill of the selected tab in a pane that does not have focus.
    public var unfocusedPaneFillHex: String

    /// Hex color of the selected tab's title in the focused pane.
    public var titleHex: String

    /// Hex color of the selected tab's title in a pane that does not have focus.
    public var unfocusedPaneTitleHex: String

    /// Hex color of the indicator on the selected tab's bottom edge in the focused pane.
    public var indicatorHex: String

    /// Hex color of the indicator on the selected tab's bottom edge in a pane that does not have focus.
    public var unfocusedPaneIndicatorHex: String

    /// Thickness of the indicator in points, clamped to the tab bar height when drawn.
    public var indicatorThickness: CGFloat

    /// Whether the selected tab's title is semibold instead of regular.
    public var boldsSelectedTitle: Bool

    /// Creates a style from the colors of each state; the indicator is 2 pt thick and the title bold unless told otherwise.
    public init(
        fillHex: String,
        inactiveWindowFillHex: String,
        unfocusedPaneFillHex: String,
        titleHex: String,
        unfocusedPaneTitleHex: String,
        indicatorHex: String,
        unfocusedPaneIndicatorHex: String,
        indicatorThickness: CGFloat = 2,
        boldsSelectedTitle: Bool = true
    ) {
        self.fillHex = fillHex
        self.inactiveWindowFillHex = inactiveWindowFillHex
        self.unfocusedPaneFillHex = unfocusedPaneFillHex
        self.titleHex = titleHex
        self.unfocusedPaneTitleHex = unfocusedPaneTitleHex
        self.indicatorHex = indicatorHex
        self.unfocusedPaneIndicatorHex = unfocusedPaneIndicatorHex
        self.indicatorThickness = indicatorThickness
        self.boldsSelectedTitle = boldsSelectedTitle
    }
}

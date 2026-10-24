import AppKit
import SwiftUI

/// The colors and title weight of the selected tab, resolved from a ``SelectedTabStyle`` for one pane and window state.
struct SelectedTabPaint {
    /// Fill behind the selected tab.
    let fill: NSColor

    /// Color of the selected tab's title.
    let title: NSColor

    /// Color of the indicator on the selected tab's bottom edge.
    let indicator: NSColor

    /// Weight of the selected tab's title.
    let titleWeight: Font.Weight

    /// Resolves the paint for a pane's focus and its window's key state.
    ///
    /// The focused pane uses the accent colors, with a softer fill while the app is inactive (bright while its window is key or main in the active app).
    /// Any other pane uses the unfocused colors whatever its window is doing. A color that is not
    /// valid hex falls back to no fill, the label color or the system accent color.
    init(style: SelectedTabStyle, isPaneFocused: Bool, isWindowKey: Bool) {
        let fillHex: String
        let titleHex: String
        let indicatorHex: String
        if isPaneFocused {
            fillHex = isWindowKey ? style.fillHex : style.inactiveWindowFillHex
            titleHex = style.titleHex
            indicatorHex = style.indicatorHex
        } else {
            fillHex = style.unfocusedPaneFillHex
            titleHex = style.unfocusedPaneTitleHex
            indicatorHex = style.unfocusedPaneIndicatorHex
        }
        fill = TabBarColors.nsColor(hex: fillHex) ?? .clear
        title = TabBarColors.nsColor(hex: titleHex) ?? .labelColor
        indicator = TabBarColors.nsColor(hex: indicatorHex) ?? .controlAccentColor
        titleWeight = style.boldsSelectedTitle ? .semibold : .regular
    }
}

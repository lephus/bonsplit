import AppKit
import SwiftUI

/// A tab's agent activity glyph, shown in place of the tab icon: an ``ActivityGlyphView``.
struct TabActivityGlyph: NSViewRepresentable {
    let kind: TabActivity.Kind
    let style: TitleEffectStyle
    let pointSize: CGFloat
    /// Whether the host presents the bar; see ``BonsplitController/isPresentationActive``.
    let isPresentationActive: Bool
    /// The environment the view is created with.
    let environment: any TitleEffectEnvironment

    func makeNSView(context: Context) -> ActivityGlyphView {
        ActivityGlyphView(environment: environment)
    }

    func updateNSView(_ view: ActivityGlyphView, context: Context) {
        view.isPresentationActive = isPresentationActive
        view.configure(kind: kind, style: style, pointSize: pointSize)
    }
}

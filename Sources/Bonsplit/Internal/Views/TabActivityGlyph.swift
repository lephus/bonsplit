import AppKit
import SwiftUI

/// A tab's agent activity glyph, shown in place of the tab icon: an ``ActivityGlyphView``.
struct TabActivityGlyph: NSViewRepresentable {
    let kind: TabActivity.Kind
    let style: TitleEffectStyle
    let pointSize: CGFloat

    func makeNSView(context: Context) -> ActivityGlyphView {
        ActivityGlyphView()
    }

    func updateNSView(_ view: ActivityGlyphView, context: Context) {
        view.configure(kind: kind, style: style, pointSize: pointSize)
    }
}

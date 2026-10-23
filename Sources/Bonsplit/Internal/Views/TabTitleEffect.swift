import AppKit
import SwiftUI

/// A tab title's agent activity effect: a ``TitleEffectView`` laid over the title text.
struct TabTitleEffect: NSViewRepresentable {
    let title: String
    let font: NSFont
    let kind: TabActivity.Kind
    let style: TitleEffectStyle

    func makeNSView(context: Context) -> TitleEffectView {
        TitleEffectView()
    }

    func updateNSView(_ view: TitleEffectView, context: Context) {
        view.configure(
            text: NSAttributedString(string: title, attributes: [.font: font]),
            maximumNumberOfLines: 1,
            kind: kind,
            style: style
        )
    }
}

import AppKit
import SwiftUI

/// A tab title's agent activity effect: a ``TitleEffectView`` laid over the title text.
struct TabTitleEffect: NSViewRepresentable {
    let title: String
    let font: NSFont
    let kind: TabActivity.Kind
    let style: TitleEffectStyle
    /// Whether the host presents the bar; see ``BonsplitController/isPresentationActive``.
    let isPresentationActive: Bool
    /// The environment the view is created with.
    let environment: any TitleEffectEnvironment

    func makeNSView(context: Context) -> TitleEffectView {
        TitleEffectView(environment: environment)
    }

    func updateNSView(_ view: TitleEffectView, context: Context) {
        view.isPresentationActive = isPresentationActive
        view.configure(
            text: NSAttributedString(string: title, attributes: [.font: font]),
            maximumNumberOfLines: 1,
            kind: kind,
            style: style
        )
    }
}

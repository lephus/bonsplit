import AppKit
import SwiftUI

/// A tab title's agent activity effect: a ``TitleEffectView`` laid over the title text.
///
/// The tab remembers which highlight generation its title already flashed for, so an effect that
/// SwiftUI builds again (after the activity paused, or when the tab moved to another pane) does
/// not flash again for the same skill or workflow.
struct TabTitleEffect: NSViewRepresentable {
    let tab: TabItem
    let title: String
    let font: NSFont
    let activity: TabActivity
    let style: TitleEffectStyle

    func makeNSView(context: Context) -> TitleEffectView {
        let view = TitleEffectView()
        view.flashedGeneration = tab.flashedActivityGeneration
        return view
    }

    func updateNSView(_ view: TitleEffectView, context: Context) {
        view.configure(
            text: NSAttributedString(string: title, attributes: [.font: font]),
            maximumNumberOfLines: 1,
            kind: activity.kind,
            generation: activity.generation,
            style: style
        )
        tab.flashedActivityGeneration = view.flashedGeneration
    }
}

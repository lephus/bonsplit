import AppKit
import SwiftUI

/// The one-time wash over a whole tab when its agent starts a skill or a workflow: an ``ActivityFlashView``.
///
/// The tab remembers which generation it already flashed for, so a flash view that SwiftUI builds
/// again (after the activity paused, or when the tab moved to another pane) does not flash again
/// for the same skill or workflow.
struct TabActivityFlash: NSViewRepresentable {
    let tab: TabItem
    let activity: TabActivity
    let style: TitleEffectStyle
    /// Whether the host presents the bar; see ``BonsplitController/isPresentationActive``.
    let isPresentationActive: Bool
    /// The environment the view is created with.
    let environment: any TitleEffectEnvironment

    func makeNSView(context: Context) -> ActivityFlashView {
        let view = ActivityFlashView(environment: environment)
        view.flashedGeneration = tab.flashedActivityGeneration
        return view
    }

    func updateNSView(_ view: ActivityFlashView, context: Context) {
        // Presentation first: a flash for a generation that arrives while the bar is not presented is dropped.
        view.isPresentationActive = isPresentationActive
        view.configure(kind: activity.kind, generation: activity.generation, style: style)
        tab.flashedActivityGeneration = view.flashedGeneration
    }
}

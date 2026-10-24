import AppKit
import SwiftUI

/// The one-time wash over a whole tab when its agent starts a skill or a workflow: an ``ActivityFlashView``.
///
/// The tab remembers which generation it already flashed for, so a flash view that SwiftUI builds
/// again (after the activity paused, after the bar was unmounted, or when the tab moved to another
/// pane of the same controller) does not flash again for the same skill or workflow. A generation
/// that started while the tab was hidden is in that memory too (see
/// `TabItem.flashedActivityGeneration`), so it never flashes late, whether the view was built
/// before or after. The memory lives on this `TabItem` only, so a tab the host rebuilds (dropped
/// into another workspace or window) may flash again if it gets the same generation on screen.
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
        // A generation the tab dropped while hidden reaches a view that is already built here.
        if view.flashedGeneration != tab.flashedActivityGeneration {
            view.flashedGeneration = tab.flashedActivityGeneration
        }
        // Presentation first: a flash for a generation that arrives while the bar is not presented is dropped.
        view.isPresentationActive = isPresentationActive
        view.configure(kind: activity.kind, generation: activity.generation, style: style)
        tab.flashedActivityGeneration = view.flashedGeneration
    }
}

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

    func makeNSView(context: Context) -> ActivityFlashView {
        let view = ActivityFlashView()
        view.flashedGeneration = tab.flashedActivityGeneration
        return view
    }

    func updateNSView(_ view: ActivityFlashView, context: Context) {
        view.configure(kind: activity.kind, generation: activity.generation, style: style)
        tab.flashedActivityGeneration = view.flashedGeneration
    }
}

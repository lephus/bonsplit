import SwiftUI

/// Reports whether the tab bar's window is key or main in the active app.
///
/// A view that declares `@Environment(\.controlActiveState)` runs its body each time its window gains
/// or loses key or main, even when the body skips the read, because SwiftUI ties the dependency to the
/// declaration. Only a bar with a selected tab style paints differently in a window that is neither key nor main in the active app,
/// so the bar puts this probe in its background for those bars alone. A bar without a style then has no
/// dependency on the window state anywhere in its tree, and adding or removing the probe never
/// rebuilds the bar.
struct TabBarWindowKeyProbe: View {
    @Environment(\.controlActiveState) private var controlActiveState

    @Binding var isWindowKey: Bool

    /// Whether a window in `state` paints the bright fill: key, or main while another window of the same
    /// app (a sheet, an alert, a panel) is key. Only a window of an app that is not in front dims, like
    /// the sidebar's session row.
    static func paintsAsKey(_ state: ControlActiveState) -> Bool {
        state != .inactive
    }

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onChange(of: Self.paintsAsKey(controlActiveState), initial: true) { _, isKey in
                isWindowKey = isKey
            }
    }
}

import SwiftUI

/// Reports whether the tab bar's window is key.
///
/// A view that declares `@Environment(\.controlActiveState)` runs its body each time its window gains
/// or loses key, even when the body skips the read, because SwiftUI ties the dependency to the
/// declaration. Only a bar with a selected tab style paints differently in a window that is not key,
/// so the bar puts this probe in its background for those bars alone. A bar without a style then has no
/// dependency on the window state anywhere in its tree, and adding or removing the probe never
/// rebuilds the bar.
struct TabBarWindowKeyProbe: View {
    @Environment(\.controlActiveState) private var controlActiveState

    @Binding var isWindowKey: Bool

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onChange(of: controlActiveState == .key, initial: true) { _, isKey in
                isWindowKey = isKey
            }
    }
}

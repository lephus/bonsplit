import SwiftUI

/// Reads whether the tab bar's window is key and hands that to the bar's content.
///
/// SwiftUI ties an `@Environment` dependency to the property's declaration, not to where it is read:
/// a view that declares `controlActiveState` but skips the read, as a bar without a style would,
/// still runs its body each time its window gains or loses key. Only a bar with a selected tab style
/// paints differently in a window that is not key, so `TabBarView` instantiates this reader for
/// those bars alone. A bar without a style has no dependency on the window state anywhere in its tree.
struct TabBarWindowKeyReader<Content: View>: View {
    @Environment(\.controlActiveState) private var controlActiveState

    private let content: (_ isWindowKey: Bool) -> Content

    init(@ViewBuilder content: @escaping (_ isWindowKey: Bool) -> Content) {
        self.content = content
    }

    var body: some View {
        content(controlActiveState == .key)
    }
}

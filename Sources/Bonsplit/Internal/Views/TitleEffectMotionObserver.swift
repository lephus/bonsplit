import AppKit

/// Calls back when an effect view may have to start or stop moving: its window's occlusion changed,
/// or the accessibility display options, which hold Reduce Motion, changed.
@MainActor
final class TitleEffectMotionObserver: NSObject {
    private let onChange: @MainActor () -> Void

    /// Starts listening for Reduce Motion changes; ``observeOcclusion(of:)`` adds a window.
    init(onChange: @escaping @MainActor () -> Void) {
        self.onChange = onChange
        super.init()
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(environmentDidChange),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil
        )
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }

    /// Listens to the occlusion of `window` instead of the previous window's.
    func observeOcclusion(of window: NSWindow?) {
        NotificationCenter.default.removeObserver(self, name: NSWindow.didChangeOcclusionStateNotification, object: nil)
        guard let window else { return }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(environmentDidChange),
            name: NSWindow.didChangeOcclusionStateNotification,
            object: window
        )
    }

    @objc private func environmentDidChange() {
        onChange()
    }
}

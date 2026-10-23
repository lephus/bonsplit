import AppKit

/// The title effect environment of the running system: window occlusion, hidden views and Reduce Motion.
@MainActor
public struct SystemTitleEffectEnvironment: TitleEffectEnvironment {
    /// Creates the system environment.
    ///
    /// Nonisolated so that it can be the default argument of the effect views' initializers.
    nonisolated public init() {}

    /// Whether Reduce Motion is on in the system's accessibility display options.
    public var reducesMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// Whether `view` is shown, in a window, and that window is at least partly visible on screen.
    ///
    /// A minimized window, or one fully covered by other windows, is not visible. A window of an app
    /// that is not frontmost still is.
    ///
    /// - Parameter view: The effect view asking.
    /// - Returns: `true` when neither `view` nor an ancestor is hidden and its window's occlusion state contains `.visible`.
    public func isVisible(_ view: NSView) -> Bool {
        guard !view.isHiddenOrHasHiddenAncestor, let window = view.window else { return false }
        return window.occlusionState.contains(.visible)
    }
}

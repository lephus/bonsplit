import AppKit

/// What a title effect needs to know about the screen and the user's settings to decide whether it may move.
///
/// ``TitleEffectView`` and ``ActivityGlyphView`` animate only while ``isVisible(_:)`` is true and
/// ``reducesMotion`` is false; otherwise they hold a still look. They ask again when their window's
/// occlusion changes, when the accessibility display options change, when they are hidden or shown,
/// and when they are configured or laid out. ``SystemTitleEffectEnvironment`` is the real one;
/// tests pass their own.
@MainActor
public protocol TitleEffectEnvironment {
    /// Whether the user asked the system to reduce motion.
    var reducesMotion: Bool { get }

    /// Whether `view` can be seen: shown, in a window, and that window not fully covered or minimized.
    ///
    /// - Parameter view: The effect view asking.
    /// - Returns: `true` when animating `view` can be seen.
    func isVisible(_ view: NSView) -> Bool
}

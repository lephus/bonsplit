import Foundation

/// What a coding agent is doing in a tab, which the tab shows as a moving title and a cycling glyph.
///
/// Hosts set it with the `activity:` argument of ``BonsplitController``'s `updateTab` and clear it
/// with `.some(nil)`; ``Tab/activity`` reports it back. A tab draws the effect only while it has an activity and
/// ``BonsplitConfiguration/Appearance/titleEffectStyle`` is set; otherwise it looks exactly as it
/// would without one. The activity is runtime state: it is never encoded with the tab.
///
/// ```swift
/// controller.updateTab(
///     tabId,
///     activity: .some(TabActivity(kind: .highlight, generation: marker.generation, accessibilityLabel: "Skill · review"))
/// )
/// ```
public struct TabActivity: Sendable, Equatable, Hashable {
    /// The kind of work the agent is doing, which picks the effect.
    public enum Kind: Sendable, Equatable, Hashable {
        /// The agent is working: a highlight sweeps across the title.
        case working
        /// The agent runs a skill or a workflow: the title flashes once, then flows through pastel colors.
        case highlight
    }

    /// The kind of work, which picks the effect.
    public var kind: Kind

    /// A counter the host raises each time a new skill or workflow starts.
    ///
    /// While the activity is ``Kind/highlight``, a generation the title has not shown yet plays the
    /// one-time flash. The same generation shown again, even after the effect paused, does not.
    /// ``Kind/working`` ignores it.
    public var generation: UInt64

    /// Words VoiceOver adds after the tab's title while the effect is drawn, such as "Thinking…".
    ///
    /// The host passes localized text; `nil` or an empty string adds nothing.
    public var accessibilityLabel: String?

    /// Creates an activity.
    ///
    /// - Parameters:
    ///   - kind: The kind of work, which picks the effect.
    ///   - generation: The counter of the skill or workflow being shown; `0` when there is none.
    ///   - accessibilityLabel: Localized words VoiceOver adds after the title, if any.
    public init(kind: Kind, generation: UInt64 = 0, accessibilityLabel: String? = nil) {
        self.kind = kind
        self.generation = generation
        self.accessibilityLabel = accessibilityLabel
    }
}

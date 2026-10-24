import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Custom UTTypes for tab drag and drop
extension UTType {
    static var tabItem: UTType {
        UTType(exportedAs: "com.splittabbar.tabitem")
    }

    static var tabTransfer: UTType {
        UTType(exportedAs: "com.splittabbar.tabtransfer", conformingTo: .data)
    }
}

/// Represents a single tab in a pane's tab bar (internal representation)
///
/// A reference type on purpose. `PaneState.tabs` is an `@Observable` property,
/// so when tabs were values, writing one tab's title wrote the whole array and
/// invalidated every view that had read it: all of `TabBarView`, not just the
/// one tab that changed. As references, a per-tab write touches only this
/// object, and observation delivers it to the `TabItemView` that read the
/// property. `PaneState.tabs` still changes on insert, remove, and move, which
/// is what `TabBarView` actually needs to see.
///
/// Equality and hashing are by `id`, as they were when this was a struct, so
/// identity comparisons behave the same.
@Observable
final class TabItem: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var hasCustomTitle: Bool
    var icon: String?
    var iconImageData: Data?
    var iconAsset: String?
    var kind: String?
    var isDirty: Bool
    var showsNotificationBadge: Bool
    var isLoading: Bool
    var isAudioMuted: Bool
    /// Whether the tab is actively producing audible audio (library
    /// consumer-defined meaning, e.g. a browser page playing sound).
    var isAudioPlaying: Bool
    var isPinned: Bool
    var showsRemoteIndicator: Bool
    var presence: TabPresence?
    /// What a coding agent is doing in this tab; drives the title effect, the activity glyph and the flash.
    /// Runtime state: never encoded.
    var activity: TabActivity?
    /// The highlight generation whose flash this tab already played or dropped.
    ///
    /// Kept on the tab rather than on the flash view, so a flash view that SwiftUI builds again
    /// (after the activity paused, after the bar was unmounted, or after the tab was dragged to
    /// another pane of the same controller, which moves this object) does not flash again for the
    /// same skill or workflow. A generation that starts where its flash cannot be seen is recorded
    /// here without one (``dropActivityFlash()``): the one a tab is created with, since no view of
    /// the new tab saw it start, and one `updateTab` hands it while it is hidden. Not observed,
    /// never encoded.
    @ObservationIgnored var flashedActivityGeneration: UInt64?

    init(
        id: UUID = UUID(),
        title: String,
        hasCustomTitle: Bool = false,
        icon: String? = "doc.text",
        iconImageData: Data? = nil,
        iconAsset: String? = nil,
        kind: String? = nil,
        isDirty: Bool = false,
        showsNotificationBadge: Bool = false,
        isLoading: Bool = false,
        isAudioMuted: Bool = false,
        isAudioPlaying: Bool = false,
        isPinned: Bool = false,
        showsRemoteIndicator: Bool = false,
        presence: TabPresence? = nil,
        activity: TabActivity? = nil
    ) {
        self.id = id
        self.title = title
        self.hasCustomTitle = hasCustomTitle
        self.icon = icon
        self.iconImageData = iconImageData
        self.iconAsset = iconAsset
        self.kind = kind
        self.isDirty = isDirty
        self.showsNotificationBadge = showsNotificationBadge
        self.isLoading = isLoading
        self.isAudioMuted = isAudioMuted
        self.isAudioPlaying = isAudioPlaying
        self.isPinned = isPinned
        self.showsRemoteIndicator = showsRemoteIndicator
        self.presence = presence
        self.activity = activity
        dropActivityFlash()
    }

    /// Takes the current highlight's generation as flashed without a flash, for a skill or
    /// workflow that started where no flash of this tab could be seen. Does nothing for other
    /// activities.
    func dropActivityFlash() {
        guard let activity, activity.kind == .highlight else { return }
        flashedActivityGeneration = activity.generation
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: TabItem, rhs: TabItem) -> Bool {
        lhs.id == rhs.id
    }

    /// `activity` and `flashedActivityGeneration` are runtime state, so they have no key.
    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case hasCustomTitle
        case icon
        case iconImageData
        case iconAsset
        case kind
        case isDirty
        case showsNotificationBadge
        case isLoading
        case isAudioMuted
        case isAudioPlaying
        case isPinned
        case showsRemoteIndicator
        case presence
    }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.title = try c.decode(String.self, forKey: .title)
        self.hasCustomTitle = try c.decodeIfPresent(Bool.self, forKey: .hasCustomTitle) ?? false
        self.icon = try c.decodeIfPresent(String.self, forKey: .icon)
        self.iconImageData = try c.decodeIfPresent(Data.self, forKey: .iconImageData)
        self.iconAsset = try c.decodeIfPresent(String.self, forKey: .iconAsset)
        self.kind = try c.decodeIfPresent(String.self, forKey: .kind)
        self.isDirty = try c.decodeIfPresent(Bool.self, forKey: .isDirty) ?? false
        self.showsNotificationBadge = try c.decodeIfPresent(Bool.self, forKey: .showsNotificationBadge) ?? false
        self.isLoading = try c.decodeIfPresent(Bool.self, forKey: .isLoading) ?? false
        self.isAudioMuted = try c.decodeIfPresent(Bool.self, forKey: .isAudioMuted) ?? false
        self.isAudioPlaying = try c.decodeIfPresent(Bool.self, forKey: .isAudioPlaying) ?? false
        self.isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        self.showsRemoteIndicator = try c.decodeIfPresent(Bool.self, forKey: .showsRemoteIndicator) ?? false
        self.presence = try c.decodeIfPresent(TabPresence.self, forKey: .presence)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(hasCustomTitle, forKey: .hasCustomTitle)
        try c.encodeIfPresent(icon, forKey: .icon)
        try c.encodeIfPresent(iconImageData, forKey: .iconImageData)
        try c.encodeIfPresent(iconAsset, forKey: .iconAsset)
        try c.encodeIfPresent(kind, forKey: .kind)
        try c.encode(isDirty, forKey: .isDirty)
        try c.encode(showsNotificationBadge, forKey: .showsNotificationBadge)
        try c.encode(isLoading, forKey: .isLoading)
        try c.encode(isAudioMuted, forKey: .isAudioMuted)
        try c.encode(isAudioPlaying, forKey: .isAudioPlaying)
        try c.encode(isPinned, forKey: .isPinned)
        try c.encode(showsRemoteIndicator, forKey: .showsRemoteIndicator)
        try c.encodeIfPresent(presence, forKey: .presence)
    }
}

// MARK: - Transferable for Drag & Drop

extension TabItem: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .tabItem)
    }
}

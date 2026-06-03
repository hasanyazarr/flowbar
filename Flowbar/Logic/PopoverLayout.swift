import CoreGraphics

enum PopoverTabKind {
    case session
    case projects
    case history
    case analytics
    case remind
}

enum PopoverLayout {
    static let projectsUseInlineExpandedCards = true
    static let projectsUseSideInspector = false
    static let sessionNoteMinHeight: CGFloat = 110
    static var sessionNotePlaceholder: String { String(localized: "What will you focus on this session?") }
    static var recentSessionNotesTitle: String { String(localized: "Recent session notes") }
    static let sessionMaxHeight: CGFloat = 520
    static let sessionProjectRowHeight: CGFloat = 36
    static let sessionRecentRowHeight: CGFloat = 25

    static func size(for tab: PopoverTabKind) -> CGSize {
        switch tab {
        case .session:
            return sessionSize(projectRowCount: 1, recentSessionCount: 0)
        case .projects:
            return CGSize(width: 480, height: 640)
        case .history:
            return CGSize(width: 480, height: 560)
        case .analytics:
            return CGSize(width: 480, height: 620)
        case .remind:
            return CGSize(width: 480, height: 560)
        }
    }

    /// Geçmiş sekmesinde "Manuel ekle" formu açıkken eklenen yükseklik.
    /// (Çok satırlı not editörü dahil.)
    static let manualEntryFormHeight: CGFloat = 285

    static func sessionSize(projectRowCount: Int, recentSessionCount: Int) -> CGSize {
        let visibleProjectRows = max(1, min(projectRowCount, 4))
        let visibleRecentRows = max(0, min(recentSessionCount, 3))
        let recentHeight = visibleRecentRows == 0
            ? 0
            : 26 + CGFloat(visibleRecentRows) * sessionRecentRowHeight
        let height = 282
            + CGFloat(visibleProjectRows) * sessionProjectRowHeight
            + recentHeight
        return CGSize(width: 480, height: min(height, sessionMaxHeight))
    }

    /// Geçmiş sekmesi boyutu. Manuel ekleme formu açıkken liste için yer kalsın diye uzar.
    static func historySize(showsManualEntryForm: Bool) -> CGSize {
        let base = size(for: .history)
        guard showsManualEntryForm else { return base }
        return CGSize(width: base.width, height: min(base.height + manualEntryFormHeight, sessionMaxHeight + manualEntryFormHeight))
    }

    static func showsInlineProjectCreation(for tab: PopoverTabKind) -> Bool {
        switch tab {
        case .session:
            return false
        case .projects:
            return true
        case .history:
            return false
        case .analytics:
            return false
        case .remind:
            return false
        }
    }
}

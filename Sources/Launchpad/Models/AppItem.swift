import AppKit
import Foundation

public enum AppCategory: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case productivity = "Productivity"
    case developer = "Developer"
    case utilities = "Utilities"
    case media = "Media & Design"
    case social = "Social & Web"
    case games = "Games"
    case other = "Other"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .all: return "ทั้งหมด"
        case .productivity: return "การทำงาน"
        case .developer: return "นักพัฒนา"
        case .utilities: return "เครื่องมือ"
        case .media: return "กราฟิกและสื่อ"
        case .social: return "โซเชียลและเว็บ"
        case .games: return "เกม"
        case .other: return "อื่นๆ"
        }
    }

    @MainActor
    public var localizedName: String {
        AppSettings.shared.appLanguage == .thai ? displayName : rawValue
    }

    public var iconName: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .productivity: return "briefcase.fill"
        case .developer: return "hammer.fill"
        case .utilities: return "wrench.and.screwdriver.fill"
        case .media: return "paintpalette.fill"
        case .social: return "bubble.left.and.bubble.right.fill"
        case .games: return "gamecontroller.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

public struct AppItem: Identifiable, Hashable, @unchecked Sendable {
    public let id: UUID
    public let name: String
    public let url: URL
    public let icon: NSImage
    public let bundleIdentifier: String?
    public let path: String
    public let category: AppCategory

    public init(
        name: String,
        url: URL,
        icon: NSImage,
        bundleIdentifier: String?,
        category: AppCategory = .other
    ) {
        self.id = UUID()
        self.name = name
        self.url = url
        self.icon = icon
        self.bundleIdentifier = bundleIdentifier
        self.path = url.path
        self.category = category
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(path)
    }

    public static func == (lhs: AppItem, rhs: AppItem) -> Bool {
        lhs.path == rhs.path
    }
}

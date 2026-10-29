import AppKit
import SwiftUI

public final class FolderItem: Identifiable, ObservableObject, @unchecked Sendable {
    public let id: UUID
    @Published public var name: String
    @Published public var apps: [AppItem]

    public init(id: UUID = UUID(), name: String = "Folder", apps: [AppItem] = []) {
        self.id = id
        self.name = name
        self.apps = apps
    }
}

public enum LaunchItem: Identifiable, Equatable {
    case app(AppItem)
    case folder(FolderItem)

    public var id: String {
        switch self {
        case .app(let a): return "app:" + a.path
        case .folder(let f): return "folder:" + f.id.uuidString
        }
    }

    public var name: String {
        switch self {
        case .app(let a): return a.name
        case .folder(let f): return f.name
        }
    }

    public static func == (lhs: LaunchItem, rhs: LaunchItem) -> Bool {
        lhs.id == rhs.id
    }
}

public struct SavedFolder: Codable {
    public let id: UUID
    public var name: String
    public var appPaths: [String]

    public init(id: UUID, name: String, appPaths: [String]) {
        self.id = id
        self.name = name
        self.appPaths = appPaths
    }
}

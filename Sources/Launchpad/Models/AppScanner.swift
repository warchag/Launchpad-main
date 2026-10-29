import AppKit
import Foundation
import Combine
import Darwin
import SQLite3

@MainActor
public final class AppScanner: ObservableObject {
    public static let shared = AppScanner()

    @Published public private(set) var allApps: [AppItem] = []
    @Published public private(set) var launchItems: [LaunchItem] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public var searchText: String = "" {
        didSet {
            if searchText != oldValue {
                selectedSearchIndex = 0
            }
        }
    }
    @Published public var selectedSearchIndex: Int = 0
    @Published public var activeFolder: FolderItem? = nil

    @Published public private(set) var runningAppPaths: Set<String> = []
    @Published public private(set) var runningBundleIDs: Set<String> = []

    private var hasLoaded: Bool = false
    private let foldersKey = "launchpad_saved_folders"
    private let itemOrderKey = "launchpad_item_order"
    private let hasImportedSystemGroupsKey = "launchpad_has_imported_system_groups"
    private var directoryMonitors: [DispatchSourceFileSystemObject] = []
    private var directoryRefreshTask: Task<Void, Never>?

    public init() {
        updateRunningApps()
        setupRunningAppsMonitor()
        setupDirectoryMonitors()
    }

    private func setupDirectoryMonitors() {
        let homeApps = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
        let pathsToWatch = ["/Applications", homeApps]

        for path in pathsToWatch {
            guard FileManager.default.fileExists(atPath: path) else { continue }
            let fd = open(path, O_EVTONLY)
            guard fd >= 0 else { continue }

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .rename, .delete],
                queue: DispatchQueue.main
            )

            source.setEventHandler { [weak self] in
                Task { @MainActor [weak self] in
                    self?.scheduleDebouncedRefresh()
                }
            }

            source.setCancelHandler {
                close(fd)
            }

            source.resume()
            directoryMonitors.append(source)
        }
    }

    private func scheduleDebouncedRefresh() {
        directoryRefreshTask?.cancel()
        directoryRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000) // 1.2s debounce
            guard !Task.isCancelled else { return }
            self?.refreshApps()
        }
    }

    private func setupRunningAppsMonitor() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateRunningApps()
            }
        }
        center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateRunningApps()
            }
        }
        center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateRunningApps()
            }
        }
    }

    public func updateRunningApps() {
        let running = NSWorkspace.shared.runningApplications
        var paths = Set<String>()
        var bundleIDs = Set<String>()
        for app in running {
            if app.activationPolicy == .regular {
                if let url = app.bundleURL {
                    paths.insert(url.standardizedFileURL.path)
                    paths.insert(url.path)
                }
                if let id = app.bundleIdentifier {
                    bundleIDs.insert(id)
                }
            }
        }
        self.runningAppPaths = paths
        self.runningBundleIDs = bundleIDs
    }

    public func isRunning(app: AppItem) -> Bool {
        if runningAppPaths.contains(app.path) || runningAppPaths.contains(URL(fileURLWithPath: app.path).standardizedFileURL.path) {
            return true
        }
        if let id = app.bundleIdentifier, runningBundleIDs.contains(id) {
            return true
        }
        return false
    }

    public func hasRunningApps(folder: FolderItem) -> Bool {
        folder.apps.contains { isRunning(app: $0) }
    }

    public func quitApp(_ app: AppItem) {
        let stdPath = URL(fileURLWithPath: app.path).standardizedFileURL.path
        for running in NSWorkspace.shared.runningApplications {
            if let bid = app.bundleIdentifier, running.bundleIdentifier == bid {
                running.terminate()
            } else if let url = running.bundleURL, (url.path == app.path || url.standardizedFileURL.path == stdPath) {
                running.terminate()
            }
        }
    }

    public func scanAppsIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        refreshApps()
    }

    public func refreshApps() {
        isLoading = true

        Task.detached(priority: .userInitiated) {
            let scanned = await Self.performScan()
            await MainActor.run {
                self.allApps = scanned

                let defaults = UserDefaults.standard
                let hasImported = defaults.bool(forKey: self.hasImportedSystemGroupsKey)
                if !hasImported && self.loadSavedFolders().isEmpty {
                    self.importSystemGroups()
                    defaults.set(true, forKey: self.hasImportedSystemGroupsKey)
                } else {
                    self.rebuildLaunchItems()
                }

                self.isLoading = false
            }
        }
    }

    // MARK: - Folders Management

    public func importSystemGroups() {
        var groupsMap: [String: [AppItem]] = [:]

        // 1. Read from macOS system Launchpad SQLite Database
        let dbGroups = Self.readSystemLaunchpadDatabase(allApps: self.allApps)
        for (groupName, apps) in dbGroups {
            if groupsMap[groupName] == nil {
                groupsMap[groupName] = apps
            } else {
                for app in apps {
                    if !groupsMap[groupName]!.contains(where: { $0.path == app.path }) {
                        groupsMap[groupName]!.append(app)
                    }
                }
            }
        }

        // 2. Fallback: If "Other" or "Utilities" is not populated, group /System/Applications/Utilities
        let utilitiesApps = allApps.filter { app in
            app.path.contains("/Utilities") || app.path.contains("/System/Applications/Utilities")
        }
        if utilitiesApps.count >= 2 {
            let targetGroup = groupsMap["Other"] != nil ? "Other" : "Utilities"
            if groupsMap[targetGroup] == nil || groupsMap[targetGroup]!.isEmpty {
                groupsMap[targetGroup] = utilitiesApps
            } else {
                for app in utilitiesApps {
                    if !groupsMap[targetGroup]!.contains(where: { $0.path == app.path }) {
                        groupsMap[targetGroup]!.append(app)
                    }
                }
            }
        }

        // 3. Save as SavedFolder models
        var saved: [SavedFolder] = []
        for (name, apps) in groupsMap where apps.count >= 2 {
            saved.append(SavedFolder(id: UUID(), name: name, appPaths: apps.map { $0.path }))
        }

        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: foldersKey)
        }

        rebuildLaunchItems()
    }

    public func rebuildLaunchItems() {
        let hidden = Set(AppSettings.shared.hiddenAppPaths)
        let visibleApps = allApps.filter { !hidden.contains($0.path) }

        let savedFolders = loadSavedFolders()
        var appMap = [String: AppItem]()
        for app in visibleApps {
            appMap[app.path] = app
        }

        var usedPaths = Set<String>()
        var items: [LaunchItem] = []

        for sf in savedFolders {
            let matchedApps = sf.appPaths.compactMap { appMap[$0] }
            if matchedApps.count >= 2 {
                for app in matchedApps {
                    usedPaths.insert(app.path)
                }
                let folder = FolderItem(id: sf.id, name: sf.name, apps: matchedApps)
                items.append(.folder(folder))
            }
        }

        for app in visibleApps {
            if !usedPaths.contains(app.path) {
                items.append(.app(app))
            }
        }

        if AppSettings.shared.autoSortAlphabetically {
            items.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        } else if let savedOrder = UserDefaults.standard.stringArray(forKey: itemOrderKey), !savedOrder.isEmpty {
            var itemDict: [String: LaunchItem] = [:]
            for item in items {
                itemDict[item.id] = item
            }
            var ordered: [LaunchItem] = []
            var placedIds = Set<String>()
            for id in savedOrder {
                if let found = itemDict[id] {
                    ordered.append(found)
                    placedIds.insert(id)
                }
            }
            for item in items where !placedIds.contains(item.id) {
                ordered.append(item)
            }
            items = ordered
        }

        self.launchItems = items
    }

    public func sortAlphabetically() {
        self.launchItems.sort { item1, item2 in
            item1.name.localizedStandardCompare(item2.name) == .orderedAscending
        }
        saveFolders()
    }

    public func moveItem(fromId: String, toId: String) {
        guard fromId != toId,
              let fromIndex = launchItems.firstIndex(where: { $0.id == fromId }),
              let toIndex = launchItems.firstIndex(where: { $0.id == toId }) else { return }

        var updated = launchItems
        let moved = updated.remove(at: fromIndex)
        updated.insert(moved, at: toIndex)
        self.launchItems = updated
        saveFolders()
    }

    public func createFolder(draggedPath: String, targetPath: String) {
        guard draggedPath != targetPath else { return }
        guard let draggedApp = allApps.first(where: { $0.path == draggedPath }),
              let targetApp = allApps.first(where: { $0.path == targetPath }) else { return }

        // Remove from existing folders if any
        removeAppFromAnyFolder(appPath: draggedPath)
        removeAppFromAnyFolder(appPath: targetPath)

        let newFolder = FolderItem(name: "Folder", apps: [targetApp, draggedApp])

        var newItems: [LaunchItem] = []
        for item in launchItems {
            switch item {
            case .app(let a):
                if a.path == targetPath {
                    newItems.append(.folder(newFolder))
                } else if a.path != draggedPath {
                    newItems.append(item)
                }
            case .folder:
                newItems.append(item)
            }
        }

        if AppSettings.shared.autoSortAlphabetically {
            newItems.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }

        self.launchItems = newItems
        saveFolders()
    }

    public func addAppToFolder(appPath: String, folderId: UUID) {
        guard let app = allApps.first(where: { $0.path == appPath }) else { return }

        for item in launchItems {
            if case .folder(let folder) = item, folder.id == folderId {
                if !folder.apps.contains(where: { $0.path == appPath }) {
                    folder.apps.append(app)
                }
                break
            }
        }

        // Remove from top-level launchItems
        self.launchItems = launchItems.filter { item in
            if case .app(let a) = item, a.path == appPath {
                return false
            }
            return true
        }

        saveFolders()
    }

    public func removeAppFromFolder(appPath: String, folderId: UUID) {
        guard let app = allApps.first(where: { $0.path == appPath }) else { return }

        var targetFolder: FolderItem?
        for item in launchItems {
            if case .folder(let folder) = item, folder.id == folderId {
                targetFolder = folder
                break
            }
        }

        guard let folder = targetFolder else { return }
        folder.apps.removeAll(where: { $0.path == appPath })

        var newItems: [LaunchItem] = []
        for item in launchItems {
            if case .folder(let f) = item, f.id == folderId {
                if folder.apps.count == 1, let lastApp = folder.apps.first {
                    // Dissolve folder into the remaining app at this exact position
                    newItems.append(.app(lastApp))
                } else if folder.apps.count > 1 {
                    newItems.append(item)
                }

                // If not auto-sorting A-Z, place the removed app right next to the folder on the current page!
                if !AppSettings.shared.autoSortAlphabetically {
                    newItems.append(.app(app))
                }
            } else {
                newItems.append(item)
            }
        }

        // Add the removed app back to launchItems if not already placed
        if !newItems.contains(where: { if case .app(let a) = $0 { return a.path == appPath } else { return false } }) {
            newItems.append(.app(app))
        }

        if AppSettings.shared.autoSortAlphabetically {
            newItems.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }

        self.launchItems = newItems

        if folder.apps.count <= 1 {
            if activeFolder?.id == folderId {
                activeFolder = nil
            }
        }

        saveFolders()
    }

    public func renameFolder(folderId: UUID, newName: String) {
        for item in launchItems {
            if case .folder(let folder) = item, folder.id == folderId {
                folder.name = newName.isEmpty ? "Folder" : newName
                break
            }
        }
        saveFolders()
    }

    public func moveAppInFolder(folderId: UUID, fromPath: String, toPath: String) {
        guard fromPath != toPath else { return }
        for item in launchItems {
            if case .folder(let folder) = item, folder.id == folderId {
                guard let fromIndex = folder.apps.firstIndex(where: { $0.path == fromPath }),
                      let toIndex = folder.apps.firstIndex(where: { $0.path == toPath }) else { return }
                var updated = folder.apps
                let moved = updated.remove(at: fromIndex)
                updated.insert(moved, at: toIndex)
                folder.apps = updated
                saveFolders()
                break
            }
        }
    }

    public var folderCount: Int {
        launchItems.reduce(0) { count, item in
            if case .folder = item { return count + 1 }
            return count
        }
    }

    public func ungroupFolder(folderId: UUID) {
        var newItems: [LaunchItem] = []
        for item in launchItems {
            if case .folder(let folder) = item, folder.id == folderId {
                for app in folder.apps {
                    newItems.append(.app(app))
                }
            } else {
                newItems.append(item)
            }
        }

        if AppSettings.shared.autoSortAlphabetically {
            newItems.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }

        if activeFolder?.id == folderId {
            activeFolder = nil
        }

        self.launchItems = newItems
        saveFolders()
    }

    public func ungroupAllFolders() {
        var newItems: [LaunchItem] = []
        for item in launchItems {
            switch item {
            case .app(let app):
                newItems.append(.app(app))
            case .folder(let folder):
                for app in folder.apps {
                    newItems.append(.app(app))
                }
            }
        }

        if AppSettings.shared.autoSortAlphabetically {
            newItems.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }

        activeFolder = nil
        self.launchItems = newItems
        saveFolders()
    }

    private func removeAppFromAnyFolder(appPath: String) {
        for item in launchItems {
            if case .folder(let folder) = item {
                folder.apps.removeAll(where: { $0.path == appPath })
            }
        }
    }

    public func saveFolders() {
        var saved: [SavedFolder] = []
        for item in launchItems {
            if case .folder(let folder) = item, folder.apps.count >= 2 {
                saved.append(SavedFolder(id: folder.id, name: folder.name, appPaths: folder.apps.map { $0.path }))
            }
        }

        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: foldersKey)
        }
        let orderIds = launchItems.map { $0.id }
        UserDefaults.standard.set(orderIds, forKey: itemOrderKey)
    }

    private func loadSavedFolders() -> [SavedFolder] {
        guard let data = UserDefaults.standard.data(forKey: foldersKey),
              let list = try? JSONDecoder().decode([SavedFolder].self, from: data) else {
            return []
        }
        return list
    }

    // MARK: - App Scanning Engine

    private static func performScan() async -> [AppItem] {
        var appList: [AppItem] = []
        var seenPaths = Set<String>()
        var seenBundleIds = Set<String>()

        let fileManager = FileManager.default
        let homeDir = fileManager.homeDirectoryForCurrentUser

        let searchDirectories: [URL] = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "/System/Applications/Utilities"),
            URL(fileURLWithPath: "/System/Library/CoreServices/Applications"),
            homeDir.appendingPathComponent("Applications")
        ]

        for directory in searchDirectories {
            guard fileManager.fileExists(atPath: directory.path) else { continue }

            guard let contents = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey, .isApplicationKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in contents {
                if url.pathExtension == "app" {
                    processAppURL(url, into: &appList, seenPaths: &seenPaths, seenBundleIds: &seenBundleIds)
                } else if isSubdirectory(url) {
                    if let subContents = try? fileManager.contentsOfDirectory(
                        at: url,
                        includingPropertiesForKeys: [.isDirectoryKey],
                        options: [.skipsHiddenFiles]
                    ) {
                        for subURL in subContents where subURL.pathExtension == "app" {
                            processAppURL(subURL, into: &appList, seenPaths: &seenPaths, seenBundleIds: &seenBundleIds)
                        }
                    }
                }
            }
        }

        appList.sort { item1, item2 in
            item1.name.localizedStandardCompare(item2.name) == .orderedAscending
        }

        return appList
    }

    private static func isSubdirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            let ext = url.pathExtension.lowercased()
            return ext != "app" && ext != "framework" && ext != "plugin" && ext != "bundle"
        }
        return false
    }

    private static func processAppURL(
        _ url: URL,
        into appList: inout [AppItem],
        seenPaths: inout Set<String>,
        seenBundleIds: inout Set<String>
    ) {
        let canonicalPath = url.resolvingSymlinksInPath().path
        guard !seenPaths.contains(canonicalPath) else { return }

        let filename = url.deletingPathExtension().lastPathComponent
        if filename.hasSuffix("Uninstaller") || filename.hasPrefix(".") {
            return
        }

        let bundle = Bundle(url: url)
        let bundleId = bundle?.bundleIdentifier

        if let bid = bundleId, !bid.isEmpty {
            if seenBundleIds.contains(bid) {
                return
            }
            seenBundleIds.insert(bid)
        }
        seenPaths.insert(canonicalPath)

        var displayName = FileManager.default.displayName(atPath: url.path)
        if displayName.hasSuffix(".app") {
            displayName = String(displayName.dropLast(4))
        }

        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 256, height: 256)

        let category = detectCategory(bundle: bundle, url: url, name: displayName)

        let appItem = AppItem(
            name: displayName,
            url: url,
            icon: icon,
            bundleIdentifier: bundleId,
            category: category
        )
        appList.append(appItem)
    }

    private static func detectCategory(bundle: Bundle?, url: URL, name: String) -> AppCategory {
        let type = (bundle?.infoDictionary?["LSApplicationCategoryType"] as? String)?.lowercased() ?? ""
        let lowerName = name.lowercased()
        let path = url.path.lowercased()

        if type.contains("developer") || lowerName.contains("xcode") || lowerName.contains("terminal") || lowerName.contains("simulator") || lowerName.contains("git") || lowerName.contains("cursor") || lowerName.contains("vscode") || lowerName.contains("sublime") || lowerName.contains("warp") || lowerName.contains("iterm") {
            return .developer
        }
        if type.contains("games") || type.contains("game") || lowerName.contains("steam") || lowerName.contains("epic") || lowerName.contains("chess") || lowerName.contains("game") {
            return .games
        }
        if type.contains("utilities") || path.contains("/utilities") || lowerName.contains("cleanmymac") || lowerName.contains("activity monitor") || lowerName.contains("disk utility") || lowerName.contains("settings") || lowerName.contains("keychain") {
            return .utilities
        }
        if type.contains("graphics") || type.contains("photography") || type.contains("video") || type.contains("music") || lowerName.contains("photo") || lowerName.contains("photoshop") || lowerName.contains("figma") || lowerName.contains("sketch") || lowerName.contains("media") || lowerName.contains("music") || lowerName.contains("garageband") || lowerName.contains("imovie") || lowerName.contains("vlc") || lowerName.contains("quicktime") {
            return .media
        }
        if type.contains("social") || type.contains("networking") || lowerName.contains("safari") || lowerName.contains("chrome") || lowerName.contains("firefox") || lowerName.contains("edge") || lowerName.contains("browser") || lowerName.contains("slack") || lowerName.contains("discord") || lowerName.contains("telegram") || lowerName.contains("line") || lowerName.contains("messenger") || lowerName.contains("mail") || lowerName.contains("messages") || lowerName.contains("zoom") || lowerName.contains("teams") {
            return .social
        }
        if type.contains("productivity") || type.contains("business") || type.contains("finance") || lowerName.contains("notes") || lowerName.contains("reminders") || lowerName.contains("calendar") || lowerName.contains("pages") || lowerName.contains("keynote") || lowerName.contains("numbers") || lowerName.contains("excel") || lowerName.contains("word") || lowerName.contains("powerpoint") || lowerName.contains("notion") || lowerName.contains("obsidian") {
            return .productivity
        }
        return .other
    }

    // Filtered apps based on search query (Bilingual: localized display name + English bundle filename)
    public var filteredApps: [AppItem] {
        let hidden = Set(AppSettings.shared.hiddenAppPaths)
        let visible = allApps.filter { !hidden.contains($0.path) }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            return visible
        }

        return visible.filter { app in
            let name = app.name.lowercased()
            let bundleFileName = app.url.deletingPathExtension().lastPathComponent.lowercased()

            if name.contains(query) || bundleFileName.contains(query) {
                return true
            }

            let words = name.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
            let acronym = words.compactMap { $0.first }.map { String($0) }.joined()
            if acronym.starts(with: query) {
                return true
            }

            let enWords = bundleFileName.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
            let enAcronym = enWords.compactMap { $0.first }.map { String($0) }.joined()
            if enAcronym.starts(with: query) {
                return true
            }

            return false
        }
    }

    // Favorite Apps list
    public var favoriteApps: [AppItem] {
        let hidden = Set(AppSettings.shared.hiddenAppPaths)
        let favoritePaths = AppSettings.shared.favoriteAppPaths
        var map: [String: AppItem] = [:]
        for app in allApps where !hidden.contains(app.path) {
            map[app.path] = app
        }
        return favoritePaths.compactMap { map[$0] }
    }

    // Recent Apps list
    public var recentApps: [AppItem] {
        let hidden = Set(AppSettings.shared.hiddenAppPaths)
        let recentPaths = AppSettings.shared.recentAppPaths
        var map: [String: AppItem] = [:]
        for app in allApps where !hidden.contains(app.path) {
            map[app.path] = app
        }
        return recentPaths.compactMap { map[$0] }
    }

    // MARK: - Read macOS System Launchpad SQLite Database
    private static func readSystemLaunchpadDatabase(allApps: [AppItem]) -> [String: [AppItem]] {
        var result: [String: [AppItem]] = [:]

        var buf = [CChar](repeating: 0, count: Int(PATH_MAX))
        guard confstr(_CS_DARWIN_USER_DIR, &buf, buf.count) > 0 else { return result }
        let rawDir = buf.withUnsafeBufferPointer { ptr in
            ptr.baseAddress.map { String(cString: $0) } ?? ""
        }
        guard !rawDir.isEmpty else { return result }
        let dbPath = rawDir + "com.apple.dock.launchpad/db/db"
        guard FileManager.default.fileExists(atPath: dbPath) else { return result }

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return result }
        defer { sqlite3_close(db) }

        let sql = """
        SELECT g.title, a.bundleid, a.title
        FROM groups g
        JOIN items page ON page.parent_id = g.item_id AND page.type = 3
        JOIN items app_item ON app_item.parent_id = page.rowid AND app_item.type = 4
        JOIN apps a ON a.item_id = app_item.rowid
        WHERE g.title IS NOT NULL AND g.title != ''
        ORDER BY g.title, app_item.ordering;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return result }
        defer { sqlite3_finalize(stmt) }

        var byBundleId: [String: AppItem] = [:]
        var byName: [String: AppItem] = [:]
        for app in allApps {
            if let bid = app.bundleIdentifier, !bid.isEmpty {
                byBundleId[bid] = app
            }
            byName[app.name.lowercased()] = app
        }

        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let groupTitlePtr = sqlite3_column_text(stmt, 0) else { continue }
            let groupTitle = String(cString: groupTitlePtr)
            let bundleId = sqlite3_column_text(stmt, 1).map { String(cString: $0) }
            let appTitle = sqlite3_column_text(stmt, 2).map { String(cString: $0) }

            var matchedApp: AppItem?
            if let bid = bundleId, let app = byBundleId[bid] {
                matchedApp = app
            } else if let title = appTitle, let app = byName[title.lowercased()] {
                matchedApp = app
            }

            if let app = matchedApp {
                if result[groupTitle] == nil {
                    result[groupTitle] = []
                }
                if !result[groupTitle]!.contains(where: { $0.path == app.path }) {
                    result[groupTitle]!.append(app)
                }
            }
        }

        return result
    }
}

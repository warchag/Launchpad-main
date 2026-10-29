import AppKit
import SwiftUI
import ServiceManagement
import Carbon

@MainActor
public final class AppSettings: ObservableObject {
    public static let shared = AppSettings()

    // Standard native macOS Launchpad icon size (large and crisp)
    public static let standardIconSize: CGFloat = 82.0
    public static let standardGridColumns: Int = 7
    public static let standardGridRows: Int = 5

    public enum AppLanguage: String, CaseIterable, Identifiable {
        case thai = "th"
        case english = "en"

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .thai: return "ภาษาไทย (TH)"
            case .english: return "English (EN)"
            }
        }
    }

    // Key constants
    private enum Keys {
        static let iconSize = "app_icon_size"
        static let gridColumns = "app_grid_columns"
        static let gridRows = "app_grid_rows"
        static let backgroundOpacity = "app_bg_opacity"
        static let blurRadius = "app_blur_radius"
        static let blurMaterial = "app_blur_material"
        static let autoFocusSearch = "app_autofocus_search"
        static let launchAtLogin = "app_launch_at_login"
        static let showDockIcon = "app_show_dock_icon"
        static let autoSortAlphabetically = "app_auto_sort_alphabetically"
        static let shortcutPreset = "app_shortcut_preset"
        static let customKeyCode = "app_custom_key_code"
        static let customModifiers = "app_custom_modifiers"
        static let hiddenAppPaths = "app_hidden_paths"
        static let recentAppPaths = "app_recent_paths"
        static let favoriteAppPaths = "app_favorite_paths"
        static let showRecentApps = "app_show_recent_apps"
        static let enableHapticFeedback = "app_enable_haptic_feedback"
        static let hotCorner = "app_hot_corner"
        static let appLanguage = "app_language"
    }

    @Published public var appLanguage: AppLanguage {
        didSet { UserDefaults.standard.set(appLanguage.rawValue, forKey: Keys.appLanguage) }
    }

    public func tr(_ th: String, _ en: String) -> String {
        appLanguage == .thai ? th : en
    }

    // 1. Icon & Grid Settings
    @Published public var autoSortAlphabetically: Bool {
        didSet {
            UserDefaults.standard.set(autoSortAlphabetically, forKey: Keys.autoSortAlphabetically)
            if autoSortAlphabetically {
                AppScanner.shared.sortAlphabetically()
            }
        }
    }

    @Published public var iconSize: CGFloat {
        didSet { UserDefaults.standard.set(Double(iconSize), forKey: Keys.iconSize) }
    }

    @Published public var gridColumns: Int {
        didSet { UserDefaults.standard.set(gridColumns, forKey: Keys.gridColumns) }
    }

    @Published public var gridRows: Int {
        didSet { UserDefaults.standard.set(gridRows, forKey: Keys.gridRows) }
    }

    // 2. Visual & Appearance
    @Published public var backgroundOpacity: Double {
        didSet { UserDefaults.standard.set(backgroundOpacity, forKey: Keys.backgroundOpacity) }
    }

    @Published public var blurRadius: CGFloat {
        didSet { UserDefaults.standard.set(Double(blurRadius), forKey: Keys.blurRadius) }
    }

    @Published public var blurMaterialIndex: Int {
        didSet { UserDefaults.standard.set(blurMaterialIndex, forKey: Keys.blurMaterial) }
    }

    // 3. Behavior & Preferences
    @Published public var autoFocusSearch: Bool {
        didSet { UserDefaults.standard.set(autoFocusSearch, forKey: Keys.autoFocusSearch) }
    }

    @Published public var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: Keys.launchAtLogin)
            updateLaunchAtLogin(enabled: launchAtLogin)
        }
    }

    @Published public var showDockIcon: Bool {
        didSet {
            UserDefaults.standard.set(showDockIcon, forKey: Keys.showDockIcon)
            updateActivationPolicy()
        }
    }

    @Published public var enableHapticFeedback: Bool {
        didSet { UserDefaults.standard.set(enableHapticFeedback, forKey: Keys.enableHapticFeedback) }
    }

    @Published public var hotCorner: String {
        didSet {
            UserDefaults.standard.set(hotCorner, forKey: Keys.hotCorner)
            HotCornerManager.shared.setup()
        }
    }

    @Published public var showRecentApps: Bool {
        didSet { UserDefaults.standard.set(showRecentApps, forKey: Keys.showRecentApps) }
    }

    @Published public var recentAppPaths: [String] {
        didSet { UserDefaults.standard.set(recentAppPaths, forKey: Keys.recentAppPaths) }
    }

    @Published public var favoriteAppPaths: [String] {
        didSet { UserDefaults.standard.set(favoriteAppPaths, forKey: Keys.favoriteAppPaths) }
    }

    @Published public var hiddenAppPaths: [String] {
        didSet {
            UserDefaults.standard.set(hiddenAppPaths, forKey: Keys.hiddenAppPaths)
            AppScanner.shared.rebuildLaunchItems()
        }
    }

    // 4. Global Hotkey / Shortcut (Optional helper - default is Dock click)
    @Published public var shortcutPreset: String {
        didSet {
            UserDefaults.standard.set(shortcutPreset, forKey: Keys.shortcutPreset)
            HotKeyManager.shared.updateRegisteredHotKeys()
        }
    }

    @Published public var customKeyCode: Int {
        didSet {
            UserDefaults.standard.set(customKeyCode, forKey: Keys.customKeyCode)
            HotKeyManager.shared.updateRegisteredHotKeys()
        }
    }

    @Published public var customModifiers: Int {
        didSet {
            UserDefaults.standard.set(customModifiers, forKey: Keys.customModifiers)
            HotKeyManager.shared.updateRegisteredHotKeys()
        }
    }

    public var blurMaterial: NSVisualEffectView.Material {
        switch blurMaterialIndex {
        case 0: return .fullScreenUI
        case 1: return .hudWindow
        case 2: return .underWindowBackground
        default: return .fullScreenUI
        }
    }

    public var pageSize: Int {
        gridColumns * gridRows
    }

    public var shortcutDisplayString: String {
        switch shortcutPreset {
        case "none":
            return tr("คลิกผ่าน Dock", "Dock Click")
        case "option_space":
            return "⌥ Space"
        case "control_space":
            return "⌃ Space"
        case "command_shift_l":
            return "⇧⌘L"
        case "custom":
            return Self.formatCustomShortcut(keyCode: customKeyCode, carbonModifiers: UInt32(customModifiers))
        default:
            return tr("คลิกผ่าน Dock", "Dock Click")
        }
    }

    public static func formatCustomShortcut(keyCode: Int, carbonModifiers: UInt32) -> String {
        var str = ""
        if (carbonModifiers & UInt32(controlKey)) != 0 { str += "⌃" }
        if (carbonModifiers & UInt32(optionKey)) != 0 { str += "⌥" }
        if (carbonModifiers & UInt32(shiftKey)) != 0 { str += "⇧" }
        if (carbonModifiers & UInt32(cmdKey)) != 0 { str += "⌘" }

        switch keyCode {
        case kVK_ANSI_A: str += "A"
        case kVK_ANSI_B: str += "B"
        case kVK_ANSI_C: str += "C"
        case kVK_ANSI_D: str += "D"
        case kVK_ANSI_E: str += "E"
        case kVK_ANSI_F: str += "F"
        case kVK_ANSI_G: str += "G"
        case kVK_ANSI_H: str += "H"
        case kVK_ANSI_I: str += "I"
        case kVK_ANSI_J: str += "J"
        case kVK_ANSI_K: str += "K"
        case kVK_ANSI_L: str += "L"
        case kVK_ANSI_M: str += "M"
        case kVK_ANSI_N: str += "N"
        case kVK_ANSI_O: str += "O"
        case kVK_ANSI_P: str += "P"
        case kVK_ANSI_Q: str += "Q"
        case kVK_ANSI_R: str += "R"
        case kVK_ANSI_S: str += "S"
        case kVK_ANSI_T: str += "T"
        case kVK_ANSI_U: str += "U"
        case kVK_ANSI_V: str += "V"
        case kVK_ANSI_W: str += "W"
        case kVK_ANSI_X: str += "X"
        case kVK_ANSI_Y: str += "Y"
        case kVK_ANSI_Z: str += "Z"
        case kVK_ANSI_0: str += "0"
        case kVK_ANSI_1: str += "1"
        case kVK_ANSI_2: str += "2"
        case kVK_ANSI_3: str += "3"
        case kVK_ANSI_4: str += "4"
        case kVK_ANSI_5: str += "5"
        case kVK_ANSI_6: str += "6"
        case kVK_ANSI_7: str += "7"
        case kVK_ANSI_8: str += "8"
        case kVK_ANSI_9: str += "9"
        case kVK_Space: str += "Space"
        case kVK_Return: str += "Return"
        case kVK_Tab: str += "Tab"
        case kVK_Escape: str += "Esc"
        case kVK_Delete: str += "Delete"
        default:
            str += "Key \(keyCode)"
        }
        return str
    }

    // MARK: - Hidden Apps
    public func hideApp(path: String) {
        if !hiddenAppPaths.contains(path) {
            hiddenAppPaths.append(path)
        }
    }

    public func unhideApp(path: String) {
        hiddenAppPaths.removeAll { $0 == path }
    }

    public func unhideAllApps() {
        hiddenAppPaths.removeAll()
    }

    public func isAppHidden(path: String) -> Bool {
        hiddenAppPaths.contains(path)
    }

    // MARK: - Favorites & Recents
    public func isFavorite(path: String) -> Bool {
        favoriteAppPaths.contains(path)
    }

    public func toggleFavorite(path: String) {
        if isFavorite(path: path) {
            favoriteAppPaths.removeAll { $0 == path }
        } else {
            favoriteAppPaths.append(path)
        }
    }

    public func addFavorite(path: String) {
        if !isFavorite(path: path) {
            favoriteAppPaths.append(path)
        }
    }

    public func removeFavorite(path: String) {
        favoriteAppPaths.removeAll { $0 == path }
    }

    public func clearFavorites() {
        favoriteAppPaths.removeAll()
    }

    public func removeRecentApp(path: String) {
        recentAppPaths.removeAll { $0 == path }
    }

    // MARK: - Recent Apps
    public func recordAppLaunch(path: String) {
        var recents = recentAppPaths.filter { $0 != path }
        recents.insert(path, at: 0)
        if recents.count > 7 {
            recents = Array(recents.prefix(7))
        }
        self.recentAppPaths = recents
    }

    public func clearRecentApps() {
        self.recentAppPaths.removeAll()
    }

    private init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            Keys.iconSize: Double(AppSettings.standardIconSize),
            Keys.gridColumns: AppSettings.standardGridColumns,
            Keys.gridRows: AppSettings.standardGridRows,
            Keys.backgroundOpacity: 0.38,
            Keys.blurRadius: 45.0,
            Keys.blurMaterial: 0,
            Keys.autoFocusSearch: true,
            Keys.launchAtLogin: false,
            Keys.showDockIcon: true,
            Keys.autoSortAlphabetically: false,
            Keys.shortcutPreset: "none",
            Keys.customKeyCode: Int(kVK_Space),
            Keys.customModifiers: Int(optionKey),
            Keys.enableHapticFeedback: true,
            Keys.hotCorner: "none",
            Keys.showRecentApps: true,
            Keys.recentAppPaths: [],
            Keys.favoriteAppPaths: [],
            Keys.hiddenAppPaths: [],
            Keys.appLanguage: "th"
        ])

        self.autoSortAlphabetically = defaults.bool(forKey: Keys.autoSortAlphabetically)

        let savedIconSize = CGFloat(defaults.double(forKey: Keys.iconSize))
        self.iconSize = (64.0...96.0).contains(savedIconSize) ? savedIconSize : AppSettings.standardIconSize

        // Fixed standard macOS Launchpad grid: 7 columns × 5 rows
        self.gridColumns = AppSettings.standardGridColumns
        self.gridRows = AppSettings.standardGridRows
        defaults.set(AppSettings.standardGridColumns, forKey: Keys.gridColumns)
        defaults.set(AppSettings.standardGridRows, forKey: Keys.gridRows)

        self.blurMaterialIndex = defaults.integer(forKey: Keys.blurMaterial)

        self.backgroundOpacity = defaults.double(forKey: Keys.backgroundOpacity)
        self.blurRadius = CGFloat(defaults.double(forKey: Keys.blurRadius))
        self.autoFocusSearch = defaults.bool(forKey: Keys.autoFocusSearch)
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        self.showDockIcon = defaults.bool(forKey: Keys.showDockIcon)
        self.enableHapticFeedback = defaults.bool(forKey: Keys.enableHapticFeedback)
        self.hotCorner = defaults.string(forKey: Keys.hotCorner) ?? "none"
        self.showRecentApps = defaults.bool(forKey: Keys.showRecentApps)
        self.recentAppPaths = defaults.stringArray(forKey: Keys.recentAppPaths) ?? []
        let savedFavorites = defaults.stringArray(forKey: Keys.favoriteAppPaths)
        if let savedFavorites = savedFavorites {
            self.favoriteAppPaths = savedFavorites
        } else {
            // Seed standard favorites on initial setup if apps exist
            let defaultsSeed = [
                "/System/Applications/Safari.app",
                "/System/Applications/System Settings.app"
            ].filter { FileManager.default.fileExists(atPath: $0) }
            self.favoriteAppPaths = defaultsSeed
            defaults.set(defaultsSeed, forKey: Keys.favoriteAppPaths)
        }
        self.hiddenAppPaths = defaults.stringArray(forKey: Keys.hiddenAppPaths) ?? []
        let savedLang = defaults.string(forKey: Keys.appLanguage) ?? "th"
        self.appLanguage = AppLanguage(rawValue: savedLang) ?? .thai

        // Migrate old F-key presets to "none" (dock click)
        var savedPreset = defaults.string(forKey: Keys.shortcutPreset) ?? "none"
        if savedPreset == "f4" || savedPreset == "both_f4_and_option_space" || savedPreset == "f5" || savedPreset == "f6" {
            savedPreset = "none"
            defaults.set("none", forKey: Keys.shortcutPreset)
        }
        self.shortcutPreset = savedPreset

        self.customKeyCode = defaults.integer(forKey: Keys.customKeyCode)
        self.customModifiers = defaults.integer(forKey: Keys.customModifiers)
    }

    public func resetToDefaults() {
        autoSortAlphabetically = false
        iconSize = AppSettings.standardIconSize
        gridColumns = AppSettings.standardGridColumns
        gridRows = AppSettings.standardGridRows
        backgroundOpacity = 0.38
        blurRadius = 45.0
        blurMaterialIndex = 0
        autoFocusSearch = true
        showDockIcon = true
        enableHapticFeedback = true
        hotCorner = "none"
        showRecentApps = true
        shortcutPreset = "none"
        customKeyCode = Int(kVK_Space)
        customModifiers = Int(optionKey)
        HotCornerManager.shared.setup()
    }

    private func updateLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to toggle Launch at Login: \(error)")
            }
        }
    }

    public func updateActivationPolicy() {
        if showDockIcon {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

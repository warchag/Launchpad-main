import AppKit
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Pre-scan applications
        AppScanner.shared.scanAppsIfNeeded()

        // Setup Menu Bar Status Item
        setupStatusItem()

        // Setup Global Hotkey if configured (optional)
        HotKeyManager.shared.setup()

        // Setup Hot Corner monitor if configured
        HotCornerManager.shared.setup()

        // Apply Dock icon preference
        AppSettings.shared.updateActivationPolicy()

        // Present Launchpad on launch
        LaunchpadWindowController.shared.present()
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        LaunchpadWindowController.shared.toggle()
        return false
    }

    public func applicationWillTerminate(_ notification: Notification) {
        LaunchpadWindowController.shared.restorePresentationOptions()
    }

    private func getStatusBarImage() -> NSImage {
        if let iconPath = Bundle.main.path(forResource: "StatusBarIcon", ofType: "png"),
           let img = NSImage(contentsOfFile: iconPath) {
            img.isTemplate = true
            img.size = NSSize(width: 18, height: 18)
            return img
        }
        if let sym = NSImage(systemSymbolName: "circle.grid.3x3.fill", accessibilityDescription: "Launchpad") {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            let configured = sym.withSymbolConfiguration(config) ?? sym
            configured.isTemplate = true
            return configured
        }
        return NSImage(size: NSSize(width: 18, height: 18))
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = getStatusBarImage()
            button.imagePosition = .imageOnly
            button.action = #selector(statusBarButtonClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            let shortcut = AppSettings.shared.shortcutPreset
            button.toolTip = shortcut == "none" ? "Launchpad" : "Launchpad (\(AppSettings.shared.shortcutDisplayString))"
        }
    }

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || (event?.modifierFlags.contains(.control) ?? false) {
            showStatusMenu()
        } else {
            LaunchpadWindowController.shared.toggle()
        }
    }

    private func showStatusMenu() {
        let menu = NSMenu()
        let settings = AppSettings.shared

        let shortcut = settings.shortcutPreset
        let toggleBase = settings.tr("เปิด/ปิด Launchpad", "Toggle Launchpad")
        let toggleTitle = shortcut == "none" ? toggleBase : "\(toggleBase) (\(settings.shortcutDisplayString))"
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleLaunchpadAction), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        let settingsItem = NSMenuItem(
            title: settings.tr("การตั้งค่า...", "Settings..."),
            action: #selector(openSettingsAction),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let refreshItem = NSMenuItem(
            title: settings.tr("รีเฟรชรายการแอปพลิเคชัน", "Refresh Applications"),
            action: #selector(refreshAppsAction),
            keyEquivalent: "r"
        )
        refreshItem.target = self
        menu.addItem(refreshItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: settings.tr("ออกจาก Launchpad", "Quit Launchpad"),
            action: #selector(quitAction),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func openSettingsAction() {
        LaunchpadWindowController.shared.dismiss()
        SettingsWindowController.shared.show()
    }

    @objc private func toggleLaunchpadAction() {
        LaunchpadWindowController.shared.toggle()
    }

    @objc private func refreshAppsAction() {
        AppScanner.shared.refreshApps()
    }

    @objc private func quitAction() {
        NSApplication.shared.terminate(nil)
    }
}

import AppKit
import SwiftUI

@MainActor
public final class SettingsWindowController: NSObject, NSWindowDelegate {
    public static let shared = SettingsWindowController()

    private var window: NSWindow?

    private override init() {
        super.init()
    }

    public func show() {
        if window == nil {
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 580, height: 640),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            win.center()
            win.title = AppSettings.shared.appLanguage == .thai ? "การตั้งค่า Launchpad" : "Launchpad Settings"
            win.isReleasedWhenClosed = false
            win.delegate = self
            win.contentView = NSHostingView(rootView: SettingsView())
            self.window = win
        }

        guard let win = window else { return }
        win.title = AppSettings.shared.appLanguage == .thai ? "การตั้งค่า Launchpad" : "Launchpad Settings"
        win.center()
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func close() {
        window?.close()
    }

    public func windowWillClose(_ notification: Notification) {
        // Window closed
    }
}

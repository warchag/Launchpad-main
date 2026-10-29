import AppKit

@MainActor
public final class HotCornerManager {
    public static let shared = HotCornerManager()

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var lastTriggerTime: TimeInterval = 0

    private init() {}

    public func setup() {
        teardown()
        guard AppSettings.shared.hotCorner != "none" else { return }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            self?.checkHotCorner()
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.checkHotCorner()
            return event
        }
    }

    public func teardown() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    private func checkHotCorner() {
        let setting = AppSettings.shared.hotCorner
        guard setting != "none" else { return }

        let now = Date().timeIntervalSinceReferenceDate
        guard now - lastTriggerTime > 1.2 else { return }

        let mousePos = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mousePos, $0.frame, false) }) ?? NSScreen.main else { return }

        let frame = screen.frame
        let margin: CGFloat = 8.0

        var triggered = false
        switch setting {
        case "top_left":
            triggered = mousePos.x <= frame.minX + margin && mousePos.y >= frame.maxY - margin
        case "top_right":
            triggered = mousePos.x >= frame.maxX - margin && mousePos.y >= frame.maxY - margin
        case "bottom_left":
            triggered = mousePos.x <= frame.minX + margin && mousePos.y <= frame.minY + margin
        case "bottom_right":
            triggered = mousePos.x >= frame.maxX - margin && mousePos.y <= frame.minY + margin
        default:
            break
        }

        if triggered {
            lastTriggerTime = now
            HapticManager.shared.playAction()
            LaunchpadWindowController.shared.toggle()
        }
    }
}

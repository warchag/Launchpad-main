import AppKit
import Carbon

@MainActor
public final class HotKeyManager: ObservableObject {
    public static let shared = HotKeyManager()

    private var hotKeyRefs: [EventHotKeyRef] = []
    private var eventHandler: EventHandlerRef?
    private var isHandlerInstalled: Bool = false

    private init() {}

    public func setup() {
        installHandlerIfNeeded()
        updateRegisteredHotKeys()
    }

    private func installHandlerIfNeeded() {
        guard !isHandlerInstalled else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handlerBlock: EventHandlerUPP = { _, theEvent, _ in
            guard let theEvent = theEvent else { return noErr }
            var hkID = EventHotKeyID()
            let status = GetEventParameter(
                theEvent,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hkID
            )

            // Signature "LPAD" = 1280332880
            if status == noErr && hkID.signature == OSType(1280332880) {
                Task { @MainActor in
                    LaunchpadWindowController.shared.toggle()
                }
            }
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            handlerBlock,
            1,
            &eventType,
            nil,
            &eventHandler
        )
        isHandlerInstalled = true
    }

    public func unregisterAll() {
        for ref in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
    }

    private func registerKey(keyCode: UInt32, modifiers: UInt32, id: UInt32) {
        let hotKeyID = EventHotKeyID(signature: OSType(1280332880), id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr, let ref = ref {
            hotKeyRefs.append(ref)
        }
    }

    public func updateRegisteredHotKeys() {
        unregisterAll()

        let preset = AppSettings.shared.shortcutPreset

        switch preset {
        case "option_space":
            registerKey(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey), id: 1001)
        case "control_space":
            registerKey(keyCode: UInt32(kVK_Space), modifiers: UInt32(controlKey), id: 1001)
        case "command_shift_l":
            registerKey(keyCode: UInt32(kVK_ANSI_L), modifiers: UInt32(cmdKey | shiftKey), id: 1001)
        case "custom":
            let code = AppSettings.shared.customKeyCode
            let mods = AppSettings.shared.customModifiers
            if code > 0 {
                registerKey(keyCode: UInt32(code), modifiers: UInt32(mods), id: 1001)
            }
        case "none":
            break
        default:
            break
        }
    }

    public func matchesCurrentShortcut(event: NSEvent) -> Bool {
        let preset = AppSettings.shared.shortcutPreset
        guard preset != "none" else { return false }

        let keyCode = Int(event.keyCode)
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])

        switch preset {
        case "option_space":
            return keyCode == kVK_Space && flags.contains(.option)
        case "control_space":
            return keyCode == kVK_Space && flags.contains(.control)
        case "command_shift_l":
            return keyCode == kVK_ANSI_L && flags.contains([.command, .shift])
        case "custom":
            let code = AppSettings.shared.customKeyCode
            let mods = AppSettings.shared.customModifiers
            var expectedFlags: NSEvent.ModifierFlags = []
            if (mods & Int(cmdKey)) != 0 { expectedFlags.insert(.command) }
            if (mods & Int(optionKey)) != 0 { expectedFlags.insert(.option) }
            if (mods & Int(controlKey)) != 0 { expectedFlags.insert(.control) }
            if (mods & Int(shiftKey)) != 0 { expectedFlags.insert(.shift) }
            return keyCode == code && flags == expectedFlags
        default:
            return false
        }
    }
}

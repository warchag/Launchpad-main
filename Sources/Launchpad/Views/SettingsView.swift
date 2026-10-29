import SwiftUI
import Carbon

public struct SettingsView: View {
    @ObservedObject var settings: AppSettings = .shared
    @ObservedObject var scanner: AppScanner = .shared
    @State private var isRecordingShortcut: Bool = false
    @State private var shortcutMonitor: Any?
    @State private var isCopiedDonate: Bool = false
    @State private var showPromptPayQR: Bool = true
    @State private var promptPayQRImage: NSImage? = nil

    public init() {}

    private func tr(_ th: String, _ en: String) -> String {
        settings.appLanguage == .thai ? th : en
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    // Language Switcher Header
                    languagePickerHeader

                    Divider()

                    generalSection

                    Divider()

                    appearanceSection

                    Divider()

                    layoutSection

                    Divider()

                    contactSection
                }
                .padding(24)
            }

            Divider()

            // Footer
            HStack {
                Button(tr("คืนค่าเริ่มต้น", "Reset to Defaults")) {
                    settings.resetToDefaults()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(.secondary)

                Spacer()

                Button(tr("เสร็จสิ้น", "Done")) {
                    stopRecording()
                    SettingsWindowController.shared.close()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 580, height: 640)
        .onAppear {
            if promptPayQRImage == nil {
                promptPayQRImage = PromptPayQRGenerator.generateQRCodeImage(mobile: "0959201930", size: 240)
            }
        }
        .onDisappear {
            stopRecording()
        }
    }

    // Language Selector Bar
    private var languagePickerHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "globe")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 1) {
                Text(tr("ภาษา / Language", "Language / ภาษา"))
                    .font(.headline)
                Text(tr("เลือกภาษาสำหรับเมนูและการตั้งค่า", "Select language for settings and interface"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Picker("", selection: $settings.appLanguage) {
                ForEach(AppSettings.AppLanguage.allCases) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 210)
        }
        .padding(.vertical, 2)
    }

    // 1. Layout & Icons Tab
    private var layoutSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Icon Size Slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(tr("ขนาดไอคอนแอป (Icon Size)", "App Icon Size"))
                        .font(.headline)
                    Spacer()
                    Text("\(Int(settings.iconSize)) px")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(.accentColor)
                }

                Slider(value: $settings.iconSize, in: 64...96, step: 2)

                Text(tr("ปรับขนาดไอคอนแอปและโฟลเดอร์ในหน้า Launchpad (ค่ามาตรฐาน 82 px)",
                        "Adjust app and folder icon size on the Launchpad grid (Default: 82 px)."))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Icon Organization & Sorting
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(tr("การจัดเรียงไอคอนและโฟลเดอร์", "Icon & Folder Organization"))
                        .font(.headline)

                    Spacer()

                    Text(tr("แอปทั้งหมด \(scanner.allApps.count) แอป • \(scanner.folderCount) โฟลเดอร์",
                            "\(scanner.allApps.count) Apps • \(scanner.folderCount) Folders"))
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.secondary.opacity(0.1)))
                }

                Toggle(isOn: $settings.autoSortAlphabetically) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr("จัดเรียงแอปทั้งหมดตามตัวอักษร (ก-ฮ / A-Z) อัตโนมัติ", "Automatically sort all apps alphabetically (A-Z)"))
                            .font(.system(size: 13, weight: .medium))
                        Text(settings.autoSortAlphabetically
                             ? tr("แอปและโฟลเดอร์จะจัดเรียงตามลำดับ ก-ฮ / A-Z เสมอ เมื่อนำแอปออกจากโฟลเดอร์จะกลับเข้าตำแหน่งตามตัวอักษรทันที",
                                  "Apps and folders remain sorted alphabetically. Removing an app from a folder immediately returns it to alphabetical order.")
                             : tr("โหมดคลาสสิก: เมื่อดึงแอปออกจากโฟลเดอร์ แอปจะวางอยู่ข้างๆ โฟลเดอร์นั้นในหน้าปัจจุบัน",
                                  "Classic mode: Removed apps are placed right beside the parent folder on the current page."))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                HStack(spacing: 8) {
                    Button(tr("จัดเรียง ก-ฮ ทันที", "Sort A-Z Now")) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            AppScanner.shared.sortAlphabetically()
                        }
                        HapticManager.shared.playClick()
                    }
                    .font(.system(size: 12))

                    Button(tr("ซิงค์โฟลเดอร์จาก macOS", "Sync macOS Folders")) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            AppScanner.shared.importSystemGroups()
                        }
                        HapticManager.shared.playAction()
                    }
                    .font(.system(size: 12))

                    if scanner.folderCount > 0 {
                        Button(tr("สลายโฟลเดอร์ทั้งหมด", "Ungroup All")) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                AppScanner.shared.ungroupAllFolders()
                            }
                            HapticManager.shared.playAction()
                        }
                        .font(.system(size: 12))
                    }

                    Spacer()

                    Button(action: {
                        AppScanner.shared.refreshApps()
                        HapticManager.shared.playClick()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .semibold))
                            Text(tr("รีเฟรชแอป", "Refresh"))
                                .font(.system(size: 12))
                        }
                    }
                }
                .padding(.top, 4)

                Text(tr("รายการแอปจะอัปเดตอัตโนมัติเมื่อติดตั้งหรือลบแอปใน /Applications",
                        "Application list updates automatically when apps are installed or removed in /Applications."))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // 2. Appearance Tab
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 22) {
            // Wallpaper Blur Intensity
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(tr("ระดับความเบลอของภาพพื้นหลัง (Wallpaper Blur)", "Wallpaper Blur Intensity"))
                        .font(.headline)
                    Spacer()
                    Text("\(Int(settings.blurRadius)) px")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(.accentColor)
                }

                Slider(value: $settings.blurRadius, in: 15...85, step: 5)

                Text(tr("ปรับระดับความเบลอของภาพวอลเปเปอร์หน้าจอปัจจุบัน", "Adjust the frosted glass blur radius of the current wallpaper."))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Background Dimming
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(tr("ความมืดของพื้นหลัง (Background Dimming)", "Background Dimming / Contrast"))
                        .font(.headline)
                    Spacer()
                    Text("\(Int(settings.backgroundOpacity * 100))%")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(.accentColor)
                }

                Slider(value: $settings.backgroundOpacity, in: 0.15...0.70, step: 0.05)

                Text(tr("ปรับเลเยอร์ความมืดเพื่อให้มองเห็นไอคอนแอปได้อย่างคมชัด", "Adjust dark vignette overlay for crisp icon visibility."))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // 3. General & Features Tab
    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Hot Corner Trigger
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr("Hot Corner (สะบัดเมาส์ชนมุมจอ)", "Hot Corner (Screen Corners)"))
                            .font(.headline)
                        Text(tr("เลื่อนเคอร์เซอร์ไปแตะมุมหน้าจอที่เลือกเพื่อเรียก Launchpad ขึ้นมาทันที",
                                "Move cursor to the selected screen corner to summon Launchpad instantly."))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Picker("", selection: $settings.hotCorner) {
                        Text(tr("ปิด (None)", "Disabled (None)")).tag("none")
                        Text(tr("มุมซ้ายบน (Top-Left)", "Top-Left Corner")).tag("top_left")
                        Text(tr("มุมขวาบน (Top-Right)", "Top-Right Corner")).tag("top_right")
                        Text(tr("มุมซ้ายล่าง (Bottom-Left)", "Bottom-Left Corner")).tag("bottom_left")
                        Text(tr("มุมขวาล่าง (Bottom-Right)", "Bottom-Right Corner")).tag("bottom_right")
                    }
                    .pickerStyle(.menu)
                    .frame(width: 175)
                }
            }

            Divider()

            // Haptic Feedback
            Toggle(isOn: $settings.enableHapticFeedback) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("การสั่นตอบสนอง (Haptic Feedback)", "Haptic Feedback"))
                        .font(.headline)
                    Text(tr("สั่นเบาๆ บนแทร็คแพดเมื่อคลิกเปิดแอป เปลี่ยนหน้า หรือลากรวมโฟลเดอร์",
                            "Gentle trackpad tactile feedback when launching apps, paging, or organizing folders."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Favorites & Recent Apps Dock
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $settings.showRecentApps) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr("แสดงแถบแอปโปรดและเปิดล่าสุด (Favorites & Recent Apps Dock)",
                                "Favorites & Recent Apps Dock"))
                            .font(.headline)
                        Text(tr("แสดงแถบมินิด็อกรวมแอปที่ปักหมุดโปรด (⭐) และแอปที่เพิ่งเปิดล่าสุด (🕒) ด้านบนของ Launchpad",
                                "Show a floating mini dock combining pinned favorites (⭐) and recently opened apps (🕒) at the top."))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if settings.showRecentApps {
                    HStack(spacing: 12) {
                        Text(tr("แอปโปรด: \(settings.favoriteAppPaths.count) แอป  •  เปิดล่าสุด: \(settings.recentAppPaths.count) แอป",
                                "Favorites: \(settings.favoriteAppPaths.count)  •  Recents: \(settings.recentAppPaths.count)"))
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        if !settings.favoriteAppPaths.isEmpty {
                            Button(tr("ล้างแอปโปรด", "Clear Favorites")) {
                                settings.clearFavorites()
                                HapticManager.shared.playClick()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        if !settings.recentAppPaths.isEmpty {
                            Button(tr("ล้างประวัติเปิดล่าสุด", "Clear Recents")) {
                                settings.clearRecentApps()
                                HapticManager.shared.playClick()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(.leading, 24)
                }
            }

            Divider()

            // Startup & Dock toggles
            Toggle(isOn: $settings.launchAtLogin) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("เปิดใช้งานอัตโนมัติเมื่อเริ่มระบบ (Launch at Login)", "Launch at Login"))
                        .font(.headline)
                    Text(tr("เปิดระบบ Launchpad ช่วยเหลืออัตโนมัติทุกครั้งเมื่อเปิดเครื่อง Mac",
                            "Automatically start Launchpad background helper on system startup."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            Toggle(isOn: $settings.showDockIcon) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("แสดงไอคอน Launchpad ไว้ใน Dock", "Show Launchpad Icon in Dock"))
                        .font(.headline)
                    Text(tr("ตรึงไอคอน Launchpad ไว้ใน Dock เพื่อให้คลิกเปิด/ปิดได้ตลอดเวลา",
                            "Pin Launchpad icon in the macOS Dock for instant one-click toggling."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            Toggle(isOn: $settings.autoFocusSearch) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("โฟกัสช่องค้นหาทันที (Auto-focus Search)", "Auto-focus Search Bar"))
                        .font(.headline)
                    Text(tr("สามารถพิมพ์ค้นหาชื่อแอปได้ทันทีเมื่อเปิดหน้า Launchpad",
                            "Type immediately to search apps upon opening Launchpad."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Global Keyboard Shortcut (Optional)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(tr("Global Keyboard Shortcut (ตัวเลือกเสริม)", "Global Keyboard Shortcut (Optional)"))
                            .font(.headline)
                        Text(tr("เลือกปุ่มลัดเสริม หรือปิดไว้เพื่อใช้การคลิกผ่าน Dock เป็นหลัก",
                                "Optional keyboard shortcut or keep disabled to toggle via Dock."))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(settings.shortcutDisplayString)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundColor(.accentColor)
                        .cornerRadius(6)
                }

                Picker("", selection: $settings.shortcutPreset) {
                    Text(tr("ปิดปุ่มลัด (คลิกผ่าน Dock อย่างเดียว)", "Disabled (Dock click only)")).tag("none")
                    Text("⌥ Space (Option + Space)").tag("option_space")
                    Text("⌃ Space (Control + Space)").tag("control_space")
                    Text("⇧⌘L (Shift + Command + L)").tag("command_shift_l")
                    Text(tr("Custom Shortcut (บันทึกปุ่มเอง)...", "Custom Shortcut (Record keys)...")).tag("custom")
                }
                .pickerStyle(.menu)

                if settings.shortcutPreset == "custom" {
                    customShortcutRecorderView
                }
            }

            Divider()

            // Hidden Apps Manager Card
            hiddenAppsCard
        }
    }

    // Hidden Apps Section
    private var hiddenAppsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "eye.slash.fill")
                            .foregroundColor(.secondary)
                        Text(tr("แอปที่ถูกซ่อนไว้ (\(settings.hiddenAppPaths.count))",
                                "Hidden Apps (\(settings.hiddenAppPaths.count))"))
                            .font(.headline)
                    }
                    Text(tr("คลิกขวาที่แอปใน Launchpad แล้วเลือก 'ซ่อนจาก Launchpad' เพื่อซ่อน",
                            "Right-click any app in Launchpad and choose 'Hide from Launchpad' to hide."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if !settings.hiddenAppPaths.isEmpty {
                    Button(tr("กู้คืนทั้งหมด (Unhide All)", "Unhide All")) {
                        withAnimation {
                            settings.unhideAllApps()
                        }
                        HapticManager.shared.playAction()
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)
                }
            }

            if settings.hiddenAppPaths.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.green)
                        .font(.system(size: 12))
                    Text(tr("ไม่มีแอปที่ถูกซ่อนอยู่ แสดงแอปครบทุกตัว", "No hidden apps. All applications are visible."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(settings.hiddenAppPaths, id: \.self) { path in
                            let filename = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
                            let icon = NSWorkspace.shared.icon(forFile: path)
                            HStack(spacing: 8) {
                                Image(nsImage: icon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 22, height: 22)
                                Text(filename)
                                    .font(.system(size: 12))
                                    .lineLimit(1)
                                Spacer()
                                Button(tr("กู้คืน", "Unhide")) {
                                    withAnimation {
                                        settings.unhideApp(path: path)
                                    }
                                    HapticManager.shared.playClick()
                                }
                                .font(.system(size: 11))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.08)))
                        }
                    }
                }
                .frame(maxHeight: 160)
            }
        }
    }

    // Custom Shortcut Recorder View
    private var customShortcutRecorderView: some View {
        HStack(spacing: 12) {
            Button(action: {
                if isRecordingShortcut {
                    stopRecording()
                } else {
                    startRecording()
                }
            }) {
                HStack(spacing: 8) {
                    if isRecordingShortcut {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text(tr("กดปุ่มบนคีย์บอร์ดที่ต้องการ... (กด Esc เพื่อยกเลิก)",
                                "Press desired shortcut keys... (Esc to cancel)"))
                            .font(.system(size: 12, weight: .medium))
                    } else {
                        Image(systemName: "record.circle")
                        Text(settings.shortcutDisplayString.isEmpty
                             ? tr("คลิกเพื่อบันทึกปุ่มลัดใหม่", "Click to record shortcut")
                             : tr("บันทึกปุ่มลัดใหม่: \(settings.shortcutDisplayString)",
                                  "Record new shortcut: \(settings.shortcutDisplayString)"))
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isRecordingShortcut ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isRecordingShortcut ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isRecordingShortcut ? 1.5 : 1)
                )
            }
            .buttonStyle(.plain)

            if isRecordingShortcut {
                Button(tr("ยกเลิก", "Cancel")) {
                    stopRecording()
                }
                .font(.system(size: 12))
            }
        }
        .padding(.vertical, 4)
    }

    private func startRecording() {
        stopRecording()
        isRecordingShortcut = true

        shortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                stopRecording()
                return nil
            }

            var carbonMods: UInt32 = 0
            if event.modifierFlags.contains(.control) { carbonMods |= UInt32(controlKey) }
            if event.modifierFlags.contains(.option) { carbonMods |= UInt32(optionKey) }
            if event.modifierFlags.contains(.shift) { carbonMods |= UInt32(shiftKey) }
            if event.modifierFlags.contains(.command) { carbonMods |= UInt32(cmdKey) }

            settings.customKeyCode = Int(event.keyCode)
            settings.customModifiers = Int(carbonMods)
            settings.shortcutPreset = "custom"

            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecordingShortcut = false
        if let monitor = shortcutMonitor {
            NSEvent.removeMonitor(monitor)
            shortcutMonitor = nil
        }
    }

    // Contact & Support Section
    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.pink)
                Text(tr("ติดต่อ & สนับสนุนผู้พัฒนา", "Contact & Support Developer"))
                    .font(.headline)
            }

            VStack(spacing: 12) {
                // GitHub Repository Row
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.purple.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.purple)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("GitHub: warchag/Launchpad")
                                .font(.system(size: 13, weight: .semibold))
                            Text("v1.2.0")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.15))
                                .foregroundColor(.purple)
                                .clipShape(Capsule())
                        }
                        Text("https://github.com/warchag/Launchpad")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Visit GitHub Repo Link
                    if let url = URL(string: "https://github.com/warchag/Launchpad") {
                        Link(destination: url) {
                            HStack(spacing: 4) {
                                Text(tr("เปิด GitHub", "GitHub"))
                                    .font(.system(size: 11.5, weight: .medium))
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.purple.opacity(0.12))
                            .foregroundColor(.purple)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.secondary.opacity(0.06)))

                // Facebook Row
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Facebook: Learn to Developer")
                            .font(.system(size: 13, weight: .semibold))
                        Text("https://www.facebook.com/learntodeveloper")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if let url = URL(string: "https://www.facebook.com/learntodeveloper") {
                        Link(destination: url) {
                            HStack(spacing: 4) {
                                Text(tr("เปิดเพจ", "Visit Page"))
                                    .font(.system(size: 11.5, weight: .medium))
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.blue.opacity(0.12))
                            .foregroundColor(.blue)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.secondary.opacity(0.06)))

                // Donate / Buy Me a Coffee Row + PromptPay QR Code
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.orange.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.orange)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(tr("โดเนท หรือ Buy Me a Coffee (พร้อมเพย์ PromptPay)",
                                    "Donate or Buy Me a Coffee (PromptPay)"))
                                .font(.system(size: 13, weight: .semibold))
                            HStack(spacing: 6) {
                                Text("นายวรจักร คงหนู")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text("•")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary.opacity(0.6))
                                Text("0959201930")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(.primary)
                            }
                        }

                        Spacer()

                        // Toggle QR code button
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showPromptPayQR.toggle()
                            }
                            HapticManager.shared.playClick()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: showPromptPayQR ? "qrcode" : "qrcode.viewfinder")
                                    .font(.system(size: 11, weight: .semibold))
                                Text(showPromptPayQR
                                     ? tr("ซ่อน QR Code", "Hide QR")
                                     : tr("QR Code", "QR Code"))
                                    .font(.system(size: 11.5, weight: .medium))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.secondary.opacity(0.12))
                            .foregroundColor(.primary)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)

                        // Copy number button
                        Button(action: {
                            let pb = NSPasteboard.general
                            pb.clearContents()
                            pb.setString("0959201930", forType: .string)
                            HapticManager.shared.playClick()
                            withAnimation(.spring(response: 0.25)) {
                                isCopiedDonate = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                withAnimation(.spring(response: 0.25)) {
                                    isCopiedDonate = false
                                }
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: isCopiedDonate ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 10.5, weight: .semibold))
                                Text(isCopiedDonate
                                     ? tr("คัดลอกแล้ว!", "Copied!")
                                     : tr("คัดลอกเบอร์", "Copy Number"))
                                    .font(.system(size: 11.5, weight: .medium))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(isCopiedDonate ? Color.green.opacity(0.16) : Color.orange.opacity(0.14))
                            .foregroundColor(isCopiedDonate ? .green : .orange)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }

                    // PromptPay QR Code Display Card
                    if showPromptPayQR {
                        VStack(spacing: 10) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.shield.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(red: 0.05, green: 0.24, blue: 0.44))
                                Text("PromptPay | พร้อมเพย์")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(red: 0.05, green: 0.24, blue: 0.44))
                            }
                            .padding(.top, 4)

                            if let qr = promptPayQRImage {
                                Image(nsImage: qr)
                                    .resizable()
                                    .interpolation(.none)
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 170, height: 170)
                                    .padding(8)
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .shadow(color: Color.black.opacity(0.12), radius: 6, y: 2)
                            } else {
                                ProgressView()
                                    .frame(width: 170, height: 170)
                            }

                            VStack(spacing: 2) {
                                Text("นายวรจักร คงหนู")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.primary)
                                Text("พร้อมเพย์: 095-920-1930")
                                    .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                                    .foregroundColor(.secondary)
                                Text(tr("สแกนด้วยแอปธนาคารทุกธนาคารเพื่อโอนเงินสนับสนุนผู้พัฒนา",
                                        "Scan with any Thai mobile banking app to support development"))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary.opacity(0.8))
                                    .padding(.top, 2)
                            }
                            .padding(.bottom, 6)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                                )
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.secondary.opacity(0.06)))
            }
        }
    }
}

import AppKit
import SwiftUI

public struct AppItemView: View {
    @ObservedObject private var settings: AppSettings = .shared
    @ObservedObject private var scanner: AppScanner = .shared
    public let app: AppItem
    public var isHighlightedTarget: Bool = false
    public var isBeingDragged: Bool = false
    public var isEditMode: Bool = false
    public var onHide: (() -> Void)? = nil
    public var onRemoveFromFolder: (() -> Void)? = nil

    @State private var isWobbling: Bool = false

    public init(
        app: AppItem,
        isHighlightedTarget: Bool = false,
        isBeingDragged: Bool = false,
        isEditMode: Bool = false,
        onHide: (() -> Void)? = nil,
        onRemoveFromFolder: (() -> Void)? = nil
    ) {
        self.app = app
        self.isHighlightedTarget = isHighlightedTarget
        self.isBeingDragged = isBeingDragged
        self.isEditMode = isEditMode
        self.onHide = onHide
        self.onRemoveFromFolder = onRemoveFromFolder
    }

    public var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottom) {
                ZStack(alignment: .topLeading) {
                // Drop Target Highlight Frame
                if isHighlightedTarget {
                    RoundedRectangle(cornerRadius: settings.iconSize * 0.22, style: .continuous)
                        .stroke(Color.white, lineWidth: 2.5)
                        .background(
                            RoundedRectangle(cornerRadius: settings.iconSize * 0.22, style: .continuous)
                                .fill(Color.white.opacity(0.35))
                        )
                        .frame(width: settings.iconSize + 14, height: settings.iconSize + 14)
                }

                Image(nsImage: app.icon)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: settings.iconSize, height: settings.iconSize)
                    .shadow(
                        color: Color.black.opacity(isBeingDragged ? 0.65 : 0.35),
                        radius: isBeingDragged ? 16 : 6,
                        x: 0,
                        y: isBeingDragged ? 10 : 3.5
                    )
                    .scaleEffect(isBeingDragged ? 1.15 : (isHighlightedTarget ? 1.08 : 1.0))

                // Delete / Hide Badge (X button in Edit / Jiggle Mode)
                if isEditMode {
                    Button(action: {
                        HapticManager.shared.playAction()
                        if let onHide = onHide {
                            onHide()
                        } else {
                            settings.hideApp(path: app.path)
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.75))
                                .frame(width: 22, height: 22)
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .offset(x: -6, y: -6)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .rotationEffect(.degrees(isEditMode ? (isWobbling ? -1.8 : 1.8) : 0))
            .animation(
                isEditMode
                    ? Animation.easeInOut(duration: 0.13).repeatForever(autoreverses: true)
                    : .default,
                value: isWobbling
            )

            // Running App Indicator Dot (like macOS Dock)
            if scanner.isRunning(app: app) {
                Circle()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: 4.5, height: 4.5)
                    .shadow(color: Color.black.opacity(0.8), radius: 2, x: 0, y: 1)
                    .offset(y: 5)
            }
        }

            // App Title with classic drop shadow
            Text(app.name)
                .font(.system(size: 12.5, weight: .regular, design: .default))
                .foregroundColor(.white)
                .shadow(color: Color.black.opacity(0.9), radius: 3, x: 0, y: 1.5)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: settings.iconSize + 34, height: 32, alignment: .top)
        }
        .frame(width: settings.iconSize + 36, height: settings.iconSize + 44)
        .contentShape(Rectangle())
        .opacity(isBeingDragged ? 0.88 : 1.0)
        .onAppear {
            if isEditMode {
                isWobbling = true
            }
        }
        .onChange(of: isEditMode) { _, newValue in
            isWobbling = newValue
        }
        .contextMenu {
            Button(action: {
                HapticManager.shared.playClick()
                settings.toggleFavorite(path: app.path)
            }) {
                if settings.isFavorite(path: app.path) {
                    Label(settings.tr("ถอนหมุดออกจากแอปโปรด", "Remove from Favorites"), systemImage: "star.slash")
                } else {
                    Label(settings.tr("ปักหมุดเป็นแอปโปรด", "Pin to Favorites"), systemImage: "star")
                }
            }

            Divider()

            Button(action: {
                NSWorkspace.shared.activateFileViewerSelecting([app.url])
            }) {
                Label(settings.tr("แสดงใน Finder", "Show in Finder"), systemImage: "folder")
            }

            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(app.path, forType: .string)
                HapticManager.shared.playClick()
            }) {
                Label(settings.tr("คัดลอกที่อยู่ไฟล์ (Path)", "Copy Path"), systemImage: "doc.on.doc")
            }

            if let onRemoveFromFolder = onRemoveFromFolder {
                Divider()

                Button(action: {
                    HapticManager.shared.playAction()
                    onRemoveFromFolder()
                }) {
                    Label(settings.tr("นำออกจากโฟลเดอร์", "Remove from Folder"), systemImage: "folder.badge.minus")
                }
            }

            if scanner.isRunning(app: app) {
                Divider()

                Button(action: {
                    HapticManager.shared.playAction()
                    scanner.quitApp(app)
                }) {
                    Label(settings.tr("ปิดแอปพลิเคชัน (\(app.name))", "Quit \(app.name)"), systemImage: "xmark.circle")
                }
            }

            Divider()

            Button(action: {
                HapticManager.shared.playAction()
                if let onHide = onHide {
                    onHide()
                } else {
                    settings.hideApp(path: app.path)
                }
            }) {
                Label(settings.tr("ซ่อนจาก Launchpad", "Hide from Launchpad"), systemImage: "eye.slash")
            }
        }
    }
}

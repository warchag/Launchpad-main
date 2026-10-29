import SwiftUI
import AppKit

public struct FavoritesAndRecentsDockView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var scanner = AppScanner.shared

    let onLaunchApp: (AppItem) -> Void

    public init(onLaunchApp: @escaping (AppItem) -> Void) {
        self.onLaunchApp = onLaunchApp
    }

    private var favoriteApps: [AppItem] {
        scanner.favoriteApps
    }

    private var recentApps: [AppItem] {
        let favPaths = Set(settings.favoriteAppPaths)
        return scanner.recentApps.filter { !favPaths.contains($0.path) }
    }

    public var body: some View {
        HStack(spacing: 14) {
            // MARK: - Section 1: Favorites (⭐)
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.yellow)
                    Text(settings.tr("แอปโปรด", "Favorites"))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding(.leading, 4)

                if favoriteApps.isEmpty {
                    Text(settings.tr("คลิกขวาที่แอปเพื่อปักหมุด", "Right-click an app to pin"))
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.45))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                } else {
                    ForEach(favoriteApps.prefix(8)) { app in
                        dockAppItem(app: app, isFavorite: true)
                    }
                }
            }

            // MARK: - Glass Divider
            Capsule()
                .fill(Color.white.opacity(0.22))
                .frame(width: 1, height: 26)
                .padding(.horizontal, 2)

            // MARK: - Section 2: Recent Apps (🕒)
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.cyan.opacity(0.95))
                    Text(settings.tr("เปิดล่าสุด", "Recent"))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                }

                if recentApps.isEmpty {
                    Text(settings.tr("ไม่มีประวัติเปิดแอป", "No recent apps"))
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.45))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                } else {
                    ForEach(recentApps.prefix(6)) { app in
                        dockAppItem(app: app, isFavorite: false)
                    }
                }
            }
            .padding(.trailing, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(
            ZStack {
                VisualEffectView(material: .fullScreenUI, blendingMode: .withinWindow)
                    .opacity(0.8)
                Color.black.opacity(0.38)
            }
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.32),
                                Color.white.opacity(0.12)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 5)
        )
    }

    @ViewBuilder
    private func dockAppItem(app: AppItem, isFavorite: Bool) -> some View {
        DockAppButton(
            app: app,
            isRunning: scanner.isRunning(app: app),
            isFavorite: isFavorite,
            onLaunch: {
                onLaunchApp(app)
            },
            onToggleFavorite: {
                settings.toggleFavorite(path: app.path)
            },
            onRemoveRecent: {
                settings.removeRecentApp(path: app.path)
            }
        )
    }
}

private struct DockAppButton: View {
    @ObservedObject private var settings: AppSettings = .shared
    @ObservedObject private var scanner: AppScanner = .shared
    let app: AppItem
    let isRunning: Bool
    let isFavorite: Bool
    let onLaunch: () -> Void
    let onToggleFavorite: () -> Void
    let onRemoveRecent: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: {
            onLaunch()
        }) {
            VStack(spacing: 2) {
                Image(nsImage: app.icon)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .scaleEffect(isHovered ? 1.18 : 1.0)
                    .shadow(color: isHovered ? Color.white.opacity(0.35) : Color.black.opacity(0.25), radius: isHovered ? 6 : 2, y: 1)
                    .animation(.spring(response: 0.22, dampingFraction: 0.75), value: isHovered)

                // Dock-style running indicator dot
                Circle()
                    .fill(Color.white.opacity(isRunning ? 0.95 : 0.0))
                    .frame(width: 3.5, height: 3.5)
                    .shadow(color: Color.white.opacity(isRunning ? 0.8 : 0.0), radius: 2)
            }
            .frame(width: 38, height: 42)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .help(app.name)
        .contextMenu {
            Button(action: {
                onLaunch()
            }) {
                Label(settings.tr("เปิด \(app.name)", "Open \(app.name)"), systemImage: "arrow.up.forward.app")
            }

            Button(action: {
                NSWorkspace.shared.activateFileViewerSelecting([app.url])
            }) {
                Label(settings.tr("แสดงใน Finder", "Show in Finder"), systemImage: "folder")
            }

            if isRunning {
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
                HapticManager.shared.playClick()
                onToggleFavorite()
            }) {
                if isFavorite {
                    Label(settings.tr("ถอนหมุดออกจากแอปโปรด", "Remove from Favorites"), systemImage: "star.slash")
                } else {
                    Label(settings.tr("ปักหมุดเป็นแอปโปรด", "Pin to Favorites"), systemImage: "star")
                }
            }

            if !isFavorite {
                Button(action: {
                    HapticManager.shared.playClick()
                    onRemoveRecent()
                }) {
                    Label(settings.tr("ลบออกจากรายการล่าสุด", "Remove from Recent"), systemImage: "clock.badge.xmark")
                }
            }
        }
    }
}


import AppKit
import SwiftUI

public struct FolderItemView: View {
    @ObservedObject private var settings: AppSettings = .shared
    @ObservedObject private var scanner: AppScanner = .shared
    @ObservedObject var folder: FolderItem
    public var isHighlightedTarget: Bool = false
    public var isBeingDragged: Bool = false
    public var isEditMode: Bool = false

    @State private var isWobbling: Bool = false

    public init(
        folder: FolderItem,
        isHighlightedTarget: Bool = false,
        isBeingDragged: Bool = false,
        isEditMode: Bool = false
    ) {
        self.folder = folder
        self.isHighlightedTarget = isHighlightedTarget
        self.isBeingDragged = isBeingDragged
        self.isEditMode = isEditMode
    }

    public var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottom) {
                // Folder Icon Preview (Frosted Squircle with Mini Icons)
                ZStack {
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

                RoundedRectangle(cornerRadius: settings.iconSize * 0.22, style: .continuous)
                    .fill(Color.white.opacity(isHighlightedTarget ? 0.35 : 0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: settings.iconSize * 0.22, style: .continuous)
                            .stroke(isHighlightedTarget ? Color.white : Color.white.opacity(0.35), lineWidth: isHighlightedTarget ? 2.0 : 1.0)
                    )
                    .shadow(
                        color: Color.black.opacity(isBeingDragged ? 0.65 : 0.35),
                        radius: isBeingDragged ? 16 : 6,
                        x: 0,
                        y: isBeingDragged ? 10 : 3.5
                    )

                // 3x3 Mini Icons Preview
                let previewApps = Array(folder.apps.prefix(9))
                let miniColumns = Array(repeating: GridItem(.fixed(settings.iconSize * 0.24), spacing: settings.iconSize * 0.05), count: 3)

                LazyVGrid(columns: miniColumns, spacing: settings.iconSize * 0.05) {
                    ForEach(previewApps) { app in
                        Image(nsImage: app.icon)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: settings.iconSize * 0.24, height: settings.iconSize * 0.24)
                    }
                }
                .padding(settings.iconSize * 0.08)
            }
            .frame(width: settings.iconSize, height: settings.iconSize)
            .scaleEffect(isBeingDragged ? 1.15 : (isHighlightedTarget ? 1.08 : 1.0))
            .rotationEffect(.degrees(isEditMode ? (isWobbling ? -1.8 : 1.8) : 0))
            .animation(
                isEditMode
                    ? Animation.easeInOut(duration: 0.13).repeatForever(autoreverses: true)
                    : .spring(response: 0.2),
                value: isWobbling
            )

            // Running App Indicator Dot (if any app inside folder is running)
            if scanner.hasRunningApps(folder: folder) {
                Circle()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: 4.5, height: 4.5)
                    .shadow(color: Color.black.opacity(0.8), radius: 2, x: 0, y: 1)
                    .offset(y: 5)
            }
        }

        // Folder Title with classic drop shadow
            Text(folder.name)
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
                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                    scanner.activeFolder = folder
                }
                HapticManager.shared.playClick()
            }) {
                Label(settings.tr("เปิดโฟลเดอร์", "Open Folder"), systemImage: "folder")
            }

            Divider()

            Button(action: {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                    scanner.ungroupFolder(folderId: folder.id)
                }
                HapticManager.shared.playAction()
            }) {
                Label(settings.tr("สลายกลุ่มโฟลเดอร์ (Ungroup)", "Ungroup Folder"), systemImage: "rectangle.grid.2x2")
            }
        }
    }
}

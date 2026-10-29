import AppKit
import SwiftUI

private struct ItemFramePreferenceKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

public struct LaunchpadOverlayView: View {
    @ObservedObject var scanner: AppScanner
    @ObservedObject var settings: AppSettings = .shared
    @ObservedObject var wallpaperManager: WallpaperManager = .shared
    public let onDismiss: () -> Void

    @State private var currentPage: Int = 0
    @State private var pageDragOffset: CGFloat = 0
    @State private var selectedCategory: AppCategory = .all
    @State private var isEditMode: Bool = false

    // Direct in-grid Drag & Drop state
    @State private var itemFrames: [String: CGRect] = [:]
    @State private var draggingItem: LaunchItem? = nil
    @State private var dragPosition: CGPoint = .zero
    @State private var currentHoverTargetId: String? = nil
    @State private var lastEdgeSwitchTime: Date = .distantPast

    private var pageSize: Int { settings.pageSize }

    private func responsiveColumns(for screenWidth: CGFloat) -> [GridItem] {
        let cols = max(1, settings.gridColumns)
        let usableWidth = max(720, screenWidth - 140)
        let baseItemWidth = settings.iconSize + 36
        let maxSpacing = (usableWidth - baseItemWidth * CGFloat(cols)) / CGFloat(max(1, cols - 1))
        let colSpacing = max(10, min(32, floor(maxSpacing)))
        return Array(repeating: GridItem(.fixed(baseItemWidth), spacing: colSpacing), count: cols)
    }

    private func responsiveRowSpacing(for screenHeight: CGFloat) -> CGFloat {
        let rows = max(1, settings.gridRows)
        let headerAndFooterHeight: CGFloat = settings.showRecentApps ? 250 : 185
        let usableHeight = max(420, screenHeight - headerAndFooterHeight)
        let itemHeight = settings.iconSize + 44
        let rawSpacing = (usableHeight - itemHeight * CGFloat(rows)) / CGFloat(max(1, rows - 1))
        return max(8, min(26, floor(rawSpacing)))
    }

    public init(scanner: AppScanner = .shared, onDismiss: @escaping () -> Void) {
        self.scanner = scanner
        self.onDismiss = onDismiss
    }

    private var displayItems: [LaunchItem] {
        if selectedCategory == .all {
            return scanner.launchItems
        }
        return scanner.launchItems.filter { item in
            switch item {
            case .app(let a):
                return a.category == selectedCategory
            case .folder(let f):
                return f.apps.contains(where: { $0.category == selectedCategory })
            }
        }
    }

    private var pages: [[LaunchItem]] {
        let items = displayItems
        guard !items.isEmpty else { return [] }
        return stride(from: 0, to: items.count, by: pageSize).map {
            Array(items[$0..<min($0 + pageSize, items.count)])
        }
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 1. Desktop Wallpaper Background Layer (Dynamic & Blurred, GPU Cached)
                if let wallpaper = wallpaperManager.blurredWallpaper {
                    Image(nsImage: wallpaper)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .blur(radius: settings.blurRadius)
                        .scaleEffect(1.10)
                        .clipped()
                        .drawingGroup()
                        .ignoresSafeArea()
                } else {
                    VisualEffectView(material: settings.blurMaterial, blendingMode: .behindWindow)
                        .ignoresSafeArea()
                }

                // 2. Frosted vibrancy tint
                VisualEffectView(material: .fullScreenUI, blendingMode: .withinWindow)
                    .opacity(0.15)
                    .ignoresSafeArea()

                // 3. Dark vignette layer for crisp contrast
                Color.black.opacity(settings.backgroundOpacity)
                    .ignoresSafeArea()

                // 4. Global background tap detector for margins/empty space
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        if isEditMode {
                            withAnimation(.spring(response: 0.25)) {
                                isEditMode = false
                            }
                            HapticManager.shared.playAction()
                        } else if draggingItem == nil {
                            onDismiss()
                        }
                    }

                // 5. Main UI Content Stack
                VStack(spacing: 0) {
                    // Top Bar: Search Bar
                    HStack {
                        Spacer()
                        SearchBarView(
                            text: $scanner.searchText,
                            onSubmit: {
                                handleSearchSubmit()
                            },
                            onEscape: {
                                if isEditMode {
                                    withAnimation { isEditMode = false }
                                } else if scanner.activeFolder != nil {
                                    withAnimation(.spring(response: 0.25)) {
                                        scanner.activeFolder = nil
                                    }
                                } else if !scanner.searchText.isEmpty {
                                    scanner.searchText = ""
                                } else {
                                    onDismiss()
                                }
                            }
                        )
                        Spacer()
                    }
                    .padding(.top, 36)
                    .padding(.bottom, 12)

                    // Category Filter Pills Bar (Shown when search is empty)
                    if scanner.searchText.isEmpty {
                        categoryPickerBar
                            .padding(.bottom, 6)
                    }

                    // Favorites & Recent Apps Dock (Shown when not searching)
                    if settings.showRecentApps && scanner.searchText.isEmpty {
                        FavoritesAndRecentsDockView(onLaunchApp: { app in
                            launchApp(app)
                        })
                        .padding(.top, 2)
                        .padding(.bottom, 8)
                    }

                    Spacer(minLength: 6)

                    // Main App Grid Area
                    if scanner.isLoading && scanner.allApps.isEmpty {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.3)
                                .colorInvert()
                            Text(settings.tr("กำลังโหลดรายการแอปพลิเคชัน...", "Loading applications..."))
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .frame(maxHeight: .infinity)
                    } else if !scanner.searchText.isEmpty {
                        // Search Results Grid
                        searchGridView(geometry: geometry)
                    } else {
                        // Paginated Classic Grid with Drag-to-Group & Jiggle Edit Mode
                        paginatedGridView(geometry: geometry)
                    }

                    Spacer(minLength: 6)

                    // Bottom Bar: Pagination Dots or App Count, Edit Mode Toggle, Settings
                    HStack {
                        Spacer()
                        if scanner.searchText.isEmpty {
                            PaginationView(
                                totalPages: max(1, pages.count),
                                currentPage: $currentPage
                            )
                        } else {
                            Text(settings.tr("พบ \(scanner.filteredApps.count) แอป", "\(scanner.filteredApps.count) apps found"))
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.black.opacity(0.25)))
                        }
                        Spacer()
                    }
                    .overlay(alignment: .trailing) {
                        HStack(spacing: 12) {
                            // Jiggle / Edit Mode Button
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    isEditMode.toggle()
                                }
                                HapticManager.shared.playAction()
                            }) {
                                Image(systemName: isEditMode ? "checkmark" : "pencil")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(isEditMode ? .green : .white.opacity(0.65))
                                    .padding(8)
                                    .background(Circle().fill(isEditMode ? Color.white.opacity(0.3) : Color.black.opacity(0.25)))
                            }
                            .buttonStyle(.plain)
                            .help(isEditMode
                                ? settings.tr("บันทึกและออกจากการจัดตำแหน่ง", "Done editing")
                                : settings.tr("จัดระเบียบไอคอน (สั่นดุ๊กดิ๊ก / ซ่อนแอป)", "Edit icons (Jiggle / Hide apps)")
                            )

                            // Settings Button
                            Button(action: {
                                onDismiss()
                                SettingsWindowController.shared.show()
                            }) {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.55))
                                    .padding(8)
                                    .background(Circle().fill(Color.black.opacity(0.25)))
                            }
                            .buttonStyle(.plain)
                            .help(settings.tr("การตั้งค่า Launchpad", "Launchpad Settings"))
                        }
                        .padding(.trailing, 36)
                    }
                    .padding(.bottom, 32)
                }
                .opacity(scanner.activeFolder != nil ? 0.0 : 1.0)
                .blur(radius: scanner.activeFolder != nil ? 20 : 0)
                .scaleEffect(scanner.activeFolder != nil ? 0.95 : 1.0)
                .animation(.spring(response: 0.32, dampingFraction: 0.82), value: scanner.activeFolder != nil)

                // 6. Floating Drag Preview Layer
                if let dragged = draggingItem {
                    FloatingDragPreview(item: dragged)
                        .position(dragPosition)
                        .allowsHitTesting(false)
                        .zIndex(500)
                }

                // 7. Active Folder Expanded Modal
                if let activeFolder = scanner.activeFolder {
                    FolderDetailView(
                        folder: activeFolder,
                        onLaunch: { selectedApp in
                            scanner.activeFolder = nil
                            launchApp(selectedApp)
                        },
                        onClose: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                scanner.activeFolder = nil
                            }
                            HapticManager.shared.playClick()
                        }
                    )
                    .zIndex(1000)
                }
            }
            .coordinateSpace(name: "LaunchpadGridSpace")
            .onPreferenceChange(ItemFramePreferenceKey.self) { frames in
                self.itemFrames = frames
            }
        }
        .ignoresSafeArea()
        .onAppear {
            scanner.scanAppsIfNeeded()
            wallpaperManager.loadWallpaper()
        }
        .onChange(of: pages.count) { _, newCount in
            if currentPage >= newCount && newCount > 0 {
                currentPage = newCount - 1
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .launchpadPreviousPage)) { _ in
            withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
                if currentPage > 0 {
                    currentPage -= 1
                    HapticManager.shared.playPage()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .launchpadNextPage)) { _ in
            withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
                if currentPage < pages.count - 1 {
                    currentPage += 1
                    HapticManager.shared.playPage()
                }
            }
        }
    }

    // Category Selector Bar
    private var categoryPickerBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AppCategory.allCases) { cat in
                    let isSelected = selectedCategory == cat
                    Button(action: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            selectedCategory = cat
                            currentPage = 0
                        }
                        HapticManager.shared.playClick()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: cat.iconName)
                                .font(.system(size: 11, weight: .semibold))
                            Text(cat.localizedName)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.32) : Color.white.opacity(0.12))
                        )
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? Color.white.opacity(0.6) : Color.clear, lineWidth: 1)
                        )
                        .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 36)
        }
    }

    // Paginated Grid View with direct touch/drag handling
    private func paginatedGridView(geometry: GeometryProxy) -> some View {
        let totalPages = max(1, pages.count)
        let gridCols = responsiveColumns(for: geometry.size.width)
        let rowSpacing = responsiveRowSpacing(for: geometry.size.height)

        return ZStack {
            // Background empty area tap catcher
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    if isEditMode {
                        withAnimation { isEditMode = false }
                        HapticManager.shared.playAction()
                    } else if draggingItem == nil {
                        onDismiss()
                    }
                }

            ForEach(0..<totalPages, id: \.self) { pageIndex in
                if abs(pageIndex - currentPage) <= 1 {
                    let pageItems = pageIndex < pages.count ? pages[pageIndex] : []

                    LazyVGrid(columns: gridCols, spacing: rowSpacing) {
                        ForEach(pageItems) { item in
                            let isBeingDragged = draggingItem?.id == item.id
                            let isTarget = currentHoverTargetId == item.id

                            Group {
                                switch item {
                                case .app(let app):
                                    AppItemView(
                                        app: app,
                                        isHighlightedTarget: isTarget,
                                        isBeingDragged: isBeingDragged,
                                        isEditMode: isEditMode,
                                        onHide: {
                                            settings.hideApp(path: app.path)
                                            scanner.rebuildLaunchItems()
                                        }
                                    )
                                case .folder(let folder):
                                    FolderItemView(
                                        folder: folder,
                                        isHighlightedTarget: isTarget,
                                        isBeingDragged: isBeingDragged,
                                        isEditMode: isEditMode
                                    )
                                }
                            }
                            .opacity(isBeingDragged ? 0.25 : 1.0)
                            .background(
                                GeometryReader { geo in
                                    if pageIndex == currentPage {
                                        Color.clear.preference(
                                            key: ItemFramePreferenceKey.self,
                                            value: [item.id: geo.frame(in: .named("LaunchpadGridSpace"))]
                                        )
                                    }
                                }
                            )
                            .onLongPressGesture(minimumDuration: 0.5) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    isEditMode = true
                                }
                                HapticManager.shared.playAction()
                            }
                            .gesture(
                                DragGesture(minimumDistance: 0, coordinateSpace: .named("LaunchpadGridSpace"))
                                    .onChanged { value in
                                        let dist = hypot(value.translation.width, value.translation.height)
                                        if dist >= 6 {
                                            if draggingItem == nil {
                                                draggingItem = item
                                                HapticManager.shared.playClick()
                                            }
                                            dragPosition = value.location

                                            // Detect hover target item under mouse
                                            if let foundId = itemFrames.first(where: { key, rect in
                                                key != item.id && rect.contains(value.location)
                                            })?.key {
                                                currentHoverTargetId = foundId
                                            } else {
                                                currentHoverTargetId = nil
                                            }

                                            // Drag near screen edge to switch pages
                                            let now = Date()
                                            if now.timeIntervalSince(lastEdgeSwitchTime) > 0.8 {
                                                if value.location.x < 45 && currentPage > 0 {
                                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                                        currentPage -= 1
                                                        HapticManager.shared.playPage()
                                                    }
                                                    lastEdgeSwitchTime = now
                                                } else if value.location.x > geometry.size.width - 45 && currentPage < totalPages - 1 {
                                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                                        currentPage += 1
                                                        HapticManager.shared.playPage()
                                                    }
                                                    lastEdgeSwitchTime = now
                                                }
                                            }
                                        }
                                    }
                                    .onEnded { value in
                                        let dist = hypot(value.translation.width, value.translation.height)
                                        if dist < 6 {
                                            // Click without dragging
                                            if isEditMode {
                                                // In edit mode, clicking doesn't launch
                                            } else {
                                                switch item {
                                                case .app(let app):
                                                    launchApp(app)
                                                case .folder(let folder):
                                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                                        scanner.activeFolder = folder
                                                    }
                                                    HapticManager.shared.playClick()
                                                }
                                            }
                                        } else {
                                            // Dropped
                                            if let targetId = currentHoverTargetId {
                                                if isEditMode {
                                                    // In Edit / Jiggle mode: reorder apps & folders
                                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                                        scanner.moveItem(fromId: item.id, toId: targetId)
                                                    }
                                                    HapticManager.shared.playAction()
                                                } else {
                                                    switch item {
                                                    case .app(let draggedApp):
                                                        if targetId.hasPrefix("app:") {
                                                            let targetPath = String(targetId.dropFirst(4))
                                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                                                scanner.createFolder(draggedPath: draggedApp.path, targetPath: targetPath)
                                                            }
                                                            HapticManager.shared.playAction()
                                                        } else if targetId.hasPrefix("folder:") {
                                                            let uuidString = String(targetId.dropFirst(7))
                                                            if let folderUuid = UUID(uuidString: uuidString) {
                                                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                                                    scanner.addAppToFolder(appPath: draggedApp.path, folderId: folderUuid)
                                                                }
                                                                HapticManager.shared.playAction()
                                                            }
                                                        }
                                                    case .folder:
                                                        // Dragging a folder onto another position reorders it
                                                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                                            scanner.moveItem(fromId: item.id, toId: targetId)
                                                        }
                                                        HapticManager.shared.playAction()
                                                    }
                                                }
                                            }
                                        }

                                        withAnimation(.spring(response: 0.25)) {
                                            draggingItem = nil
                                            currentHoverTargetId = nil
                                        }
                                    }
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .offset(x: CGFloat(pageIndex - currentPage) * geometry.size.width + pageDragOffset)
                    .animation(.interactiveSpring(), value: pageDragOffset)
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 15)
                .onChanged { value in
                    guard draggingItem == nil else { return }
                    pageDragOffset = value.translation.width
                }
                .onEnded { value in
                    guard draggingItem == nil else { return }
                    let threshold: CGFloat = 80
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
                        if value.translation.width < -threshold && currentPage < totalPages - 1 {
                            currentPage += 1
                            HapticManager.shared.playPage()
                        } else if value.translation.width > threshold && currentPage > 0 {
                            currentPage -= 1
                            HapticManager.shared.playPage()
                        }
                        pageDragOffset = 0
                    }
                }
        )
    }

    // Search Results Grid View
    private func searchGridView(geometry: GeometryProxy) -> some View {
        let gridCols = responsiveColumns(for: geometry.size.width)
        let results = scanner.filteredApps

        return ScrollView(.vertical, showsIndicators: false) {
            if results.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundColor(.white.opacity(0.4))
                    Text(settings.tr("ไม่พบแอปที่ตรงกับ \"\(scanner.searchText)\"", "No results for \"\(scanner.searchText)\""))
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, 80)
            } else {
                LazyVGrid(columns: gridCols, spacing: 20) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { index, app in
                        AppItemView(
                            app: app,
                            isHighlightedTarget: index == scanner.selectedSearchIndex,
                            isBeingDragged: false,
                            isEditMode: false
                        )
                        .onTapGesture {
                            launchApp(app)
                        }
                    }
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 20)
            }
        }
        .frame(maxHeight: .infinity)
        .background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    onDismiss()
                }
        )
    }

    private func handleSearchSubmit() {
        let results = scanner.filteredApps
        guard !results.isEmpty else { return }
        let safeIndex = min(max(0, scanner.selectedSearchIndex), results.count - 1)
        launchApp(results[safeIndex])
    }

    private func launchApp(_ app: AppItem) {
        HapticManager.shared.playAction()
        settings.recordAppLaunch(path: app.path)

        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        NSWorkspace.shared.openApplication(at: app.url, configuration: config) { _, error in
            if let error = error {
                print("Failed to open app \(app.name): \(error)")
            }
        }

        onDismiss()
    }
}

// Floating Drag Preview
private struct FloatingDragPreview: View {
    @ObservedObject private var settings: AppSettings = .shared
    let item: LaunchItem

    var body: some View {
        VStack(spacing: 8) {
            switch item {
            case .app(let app):
                Image(nsImage: app.icon)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: settings.iconSize * 1.15, height: settings.iconSize * 1.15)
                    .shadow(color: Color.black.opacity(0.65), radius: 18, x: 0, y: 10)

            case .folder(let folder):
                ZStack {
                    RoundedRectangle(cornerRadius: settings.iconSize * 0.22, style: .continuous)
                        .fill(Color.white.opacity(0.28))
                        .overlay(
                            RoundedRectangle(cornerRadius: settings.iconSize * 0.22, style: .continuous)
                                .stroke(Color.white.opacity(0.45), lineWidth: 1.5)
                        )
                        .shadow(color: Color.black.opacity(0.65), radius: 18, x: 0, y: 10)

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
                .frame(width: settings.iconSize * 1.15, height: settings.iconSize * 1.15)
            }

            Text(item.name)
                .font(.system(size: 12.5, weight: .semibold, design: .default))
                .foregroundColor(.white)
                .shadow(color: Color.black.opacity(0.9), radius: 4, x: 0, y: 2)
                .lineLimit(1)
        }
        .frame(width: settings.iconSize + 50, height: settings.iconSize + 55)
    }
}

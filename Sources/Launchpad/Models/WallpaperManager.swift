import AppKit
import CoreGraphics
import ImageIO

@MainActor
public final class WallpaperManager: ObservableObject {
    public static let shared = WallpaperManager()

    @Published public private(set) var blurredWallpaper: NSImage?
    private var currentWallpaperURL: URL?

    private init() {
        loadWallpaper()

        // Also listen for Space/Desktop changes
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(spaceChanged),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
    }

    @objc private func spaceChanged() {
        loadWallpaper()
    }

    public func loadWallpaper(for screen: NSScreen? = nil, force: Bool = false) {
        let targetScreen = screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let targetScreen = targetScreen,
              let url = NSWorkspace.shared.desktopImageURL(for: targetScreen) else {
            return
        }

        if !force && url == currentWallpaperURL && blurredWallpaper != nil {
            return
        }

        self.currentWallpaperURL = url

        Task.detached(priority: .userInitiated) {
            let image = Self.loadDownsampledImage(from: url, maxDimension: 960)
            await MainActor.run {
                self.blurredWallpaper = image
            }
        }
    }

    nonisolated private static func loadDownsampledImage(from url: URL, maxDimension: Int) -> NSImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else {
            return NSImage(contentsOf: url)
        }

        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]

        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else {
            return NSImage(contentsOf: url)
        }

        return NSImage(cgImage: thumbnail, size: NSSize(width: thumbnail.width, height: thumbnail.height))
    }
}

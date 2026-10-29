import AppKit
import SwiftUI

struct TileSpec: Identifiable {
    let id = UUID()
    let symbol: String
    let colors: [Color]
    let isHero: Bool
}

struct LauncherIconCanvas: View {
    private let tiles: [TileSpec] = [
        // Row 1
        TileSpec(symbol: "safari.fill", colors: [Color(red: 0.08, green: 0.72, blue: 0.98), Color(red: 0.12, green: 0.38, blue: 0.95)], isHero: false),
        TileSpec(symbol: "music.note", colors: [Color(red: 0.98, green: 0.28, blue: 0.45), Color(red: 0.85, green: 0.18, blue: 0.65)], isHero: false),
        TileSpec(symbol: "sparkles", colors: [Color(red: 1.00, green: 0.78, blue: 0.15), Color(red: 0.98, green: 0.42, blue: 0.10)], isHero: false),
        // Row 2
        TileSpec(symbol: "message.fill", colors: [Color(red: 0.20, green: 0.86, blue: 0.55), Color(red: 0.04, green: 0.62, blue: 0.40)], isHero: false),
        TileSpec(symbol: "paperplane.fill", colors: [Color(red: 0.45, green: 0.40, blue: 1.00), Color(red: 0.72, green: 0.25, blue: 0.98)], isHero: true),
        TileSpec(symbol: "photo.fill", colors: [Color(red: 0.22, green: 0.78, blue: 0.98), Color(red: 0.06, green: 0.48, blue: 0.72)], isHero: false),
        // Row 3
        TileSpec(symbol: "chevron.left.forwardslash.chevron.right", colors: [Color(red: 0.45, green: 0.52, blue: 0.64), Color(red: 0.18, green: 0.24, blue: 0.34)], isHero: false),
        TileSpec(symbol: "square.grid.2x2.fill", colors: [Color(red: 0.76, green: 0.44, blue: 0.98), Color(red: 0.48, green: 0.16, blue: 0.84)], isHero: false),
        TileSpec(symbol: "gearshape.fill", colors: [Color(red: 0.98, green: 0.54, blue: 0.22), Color(red: 0.90, green: 0.16, blue: 0.34)], isHero: false)
    ]

    var body: some View {
        ZStack {
            // Transparent outer canvas (1024x1024), Apple HIG standard 824x824 squircle body
            ZStack {
                // 1. Deep Aurora Midnight-Cosmos Base Squircle
                RoundedRectangle(cornerRadius: 185, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.08, green: 0.10, blue: 0.26),
                                Color(red: 0.16, green: 0.10, blue: 0.36),
                                Color(red: 0.06, green: 0.14, blue: 0.30)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // 2. Ambient Aurora Glow Orbs
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.22, green: 0.74, blue: 0.98).opacity(0.45), .clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 340
                        )
                    )
                    .frame(width: 680, height: 680)
                    .offset(x: 160, y: -170)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.68, green: 0.32, blue: 0.98).opacity(0.48), .clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 360
                        )
                    )
                    .frame(width: 720, height: 720)
                    .offset(x: -150, y: 180)

                // 3. Top Glossy Specular Sheen
                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.18), Color.white.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 900, height: 420)
                    .offset(y: -260)

                // 4. Inner Frosted Glass Plate Behind Grid
                RoundedRectangle(cornerRadius: 128, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 128, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.28), Color.white.opacity(0.06)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2.5
                            )
                    )
                    .frame(width: 684, height: 614)
                    .offset(y: 26)

                // 5. Main Content Stack: Search Pill + 3x3 App Grid + Page Dots
                VStack(spacing: 34) {
                    // Top Search Bar Pill (Signature Launchpad Header)
                    HStack(spacing: 14) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white.opacity(0.92))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.75), Color.white.opacity(0.32)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 155, height: 10)
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.42), lineWidth: 2)
                            )
                    )
                    .shadow(color: .black.opacity(0.28), radius: 10, x: 0, y: 5)

                    // 3x3 Launcher App Grid
                    VStack(spacing: 34) {
                        ForEach(0..<3, id: \.self) { row in
                            HStack(spacing: 36) {
                                ForEach(0..<3, id: \.self) { col in
                                    let tile = tiles[row * 3 + col]
                                    launcherTileView(tile)
                                }
                            }
                        }
                    }

                    // Bottom Pagination Dots
                    HStack(spacing: 18) {
                        Circle()
                            .fill(Color.white.opacity(0.38))
                            .frame(width: 11, height: 11)
                        Capsule()
                            .fill(Color.white.opacity(0.95))
                            .frame(width: 26, height: 11)
                            .shadow(color: Color.white.opacity(0.6), radius: 6)
                        Circle()
                            .fill(Color.white.opacity(0.38))
                            .frame(width: 11, height: 11)
                    }
                    .padding(.top, 2)
                }
                .offset(y: 4)
            }
            .frame(width: 824, height: 824)
            .clipShape(RoundedRectangle(cornerRadius: 185, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 185, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.55),
                                Color.white.opacity(0.18),
                                Color.white.opacity(0.08),
                                Color.white.opacity(0.28)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 4.5
                    )
            )
            .shadow(color: Color(red: 0.04, green: 0.05, blue: 0.16).opacity(0.58), radius: 28, x: 0, y: 18)
        }
        .frame(width: 1024, height: 1024)
    }

    @ViewBuilder
    private func launcherTileView(_ tile: TileSpec) -> some View {
        let size: CGFloat = tile.isHero ? 168 : 150
        let corner: CGFloat = size * 0.245

        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: tile.colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Top glossy highlight inside tile
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.32), Color.white.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .center
                    )
                )

            Image(systemName: tile.symbol)
                .font(.system(size: tile.isHero ? 74 : 64, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, Color.white.opacity(0.88)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.28), radius: 6, x: 0, y: 4)
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(tile.isHero ? 0.85 : 0.55),
                            Color.white.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: tile.isHero ? 3.5 : 2.2
                )
        )
        .shadow(
            color: tile.isHero ? tile.colors.last!.opacity(0.65) : Color.black.opacity(0.38),
            radius: tile.isHero ? 20 : 10,
            x: 0,
            y: tile.isHero ? 10 : 7
        )
    }
}

@MainActor
func renderIcons() throws {
    let outDir = URL(fileURLWithPath: "/Users/worracag/Desktop/ProJect/Launchpad/Resources")
    try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

    let renderer = ImageRenderer(content: LauncherIconCanvas())
    renderer.scale = 1.0

    guard let cgImage = renderer.cgImage else {
        fatalError("Failed to render LauncherIconCanvas to CGImage")
    }

    let bitmap = NSBitmapImageRep(cgImage: cgImage)
    guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Failed to create PNG data")
    }

    let mainPngURL = outDir.appendingPathComponent("AppIcon.png")
    try pngData.write(to: mainPngURL)
    print("Saved \(mainPngURL.path)")

    let iconsetDir = outDir.appendingPathComponent("AppIcon.iconset")
    try FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

    let sizes: [(Int, String)] = [
        (16, "icon_16x16.png"),
        (32, "icon_16x16@2x.png"),
        (32, "icon_32x32.png"),
        (64, "icon_32x32@2x.png"),
        (128, "icon_128x128.png"),
        (256, "icon_128x128@2x.png"),
        (256, "icon_256x256.png"),
        (512, "icon_256x256@2x.png"),
        (512, "icon_512x512.png"),
        (1024, "icon_512x512@2x.png")
    ]

    for (dim, name) in sizes {
        let r = ImageRenderer(
            content: LauncherIconCanvas()
                .scaleEffect(CGFloat(dim) / 1024.0)
                .frame(width: CGFloat(dim), height: CGFloat(dim))
        )
        r.scale = 1.0
        if let scaledCG = r.cgImage {
            let rep = NSBitmapImageRep(cgImage: scaledCG)
            if let data = rep.representation(using: .png, properties: [:]) {
                try data.write(to: iconsetDir.appendingPathComponent(name))
            }
        }
    }

    let icnsURL = outDir.appendingPathComponent("AppIcon.icns")
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    proc.arguments = ["-c", "icns", iconsetDir.path, "-o", icnsURL.path]
    try proc.run()
    proc.waitUntilExit()
    print("Generated \(icnsURL.path) with status \(proc.terminationStatus)")
}

try MainActor.assumeIsolated {
    try renderIcons()
}


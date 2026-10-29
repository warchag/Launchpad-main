// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Launchpad",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Launchpad",
            path: "Sources/Launchpad"
        ),
    ]
)

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Paint",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Paint",
            path: "Sources/Paint",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)

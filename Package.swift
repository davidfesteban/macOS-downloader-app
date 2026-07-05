// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacDownloader",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MacDownloader", targets: ["MacDownloader"])
    ],
    targets: [
        .executableTarget(
            name: "MacDownloader",
            path: "Sources/MacDownloader",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Gainsayer",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "Gainsayer",
            path: "Sources/Gainsayer",
            swiftSettings: [
                // Core Audio callbacks and C-style pointers fight Swift 6 strict concurrency.
                // Stay in the 5 language mode until the audio layer has settled.
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "GainsayerTests",
            dependencies: ["Gainsayer"],
            path: "Tests/GainsayerTests"
        ),
    ]
)

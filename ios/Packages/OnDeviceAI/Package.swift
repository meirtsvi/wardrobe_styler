// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "OnDeviceAI",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "OnDeviceAI", targets: ["OnDeviceAI"]),
    ],
    dependencies: [
        .package(path: "../Domain"),
    ],
    targets: [
        .target(
            name: "OnDeviceAI",
            dependencies: ["Domain"],
            resources: [.copy("Resources/persona_v1.md")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "OnDeviceAITests",
            dependencies: ["OnDeviceAI", "Domain"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)

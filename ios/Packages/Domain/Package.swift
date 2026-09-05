// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Domain",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
    ],
    targets: [
        .target(
            name: "Domain",
            resources: [
                // Symlinks to ../../shared so the app executes the same rule files as the gateway (PLAN §5.6).
                .copy("Resources/temperature.json"),
                .copy("Resources/taxonomy.json"),
                .copy("Resources/color_palette.json"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "DomainTests",
            dependencies: ["Domain"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)

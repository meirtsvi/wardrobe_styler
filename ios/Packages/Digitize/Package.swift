// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Digitize",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "Digitize", targets: ["Digitize"]),
    ],
    dependencies: [
        .package(path: "../Domain"),
    ],
    targets: [
        .target(
            name: "Digitize",
            dependencies: ["Domain"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "DigitizeTests",
            dependencies: ["Digitize", "Domain"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)

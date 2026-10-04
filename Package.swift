// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BetterNB",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "BetterNB", targets: ["BetterNB"]),
    ],
    targets: [
        .executableTarget(
            name: "BetterNB",
            path: "macos/BetterNB",
            exclude: ["Resources"]
        ),
        .testTarget(
            name: "BetterNBTests",
            dependencies: ["BetterNB"],
            path: "macos/BetterNBTests"
        ),
    ]
)

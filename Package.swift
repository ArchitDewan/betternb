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
    dependencies: [
        .package(url: "https://github.com/auth0/Auth0.swift", .upToNextMinor(from: "2.11.0")),
        .package(url: "https://github.com/mgriebling/SwiftMath", from: "1.7.1"),
    ],
    targets: [
        .executableTarget(
            name: "BetterNB",
            dependencies: [
                .product(name: "Auth0", package: "Auth0.swift"),
                .product(name: "SwiftMath", package: "SwiftMath"),
            ],
            path: "macos/BetterNB",
            exclude: ["Resources"]
        ),
        .testTarget(
            name: "BetterNBTests",
            dependencies: [
                "BetterNB",
                .product(name: "Auth0", package: "Auth0.swift"),
            ],
            path: "macos/BetterNBTests"
        ),
    ]
)

// swift-tools-version: 6.0
// SPDX-License-Identifier: GPL-3.0-or-later

import PackageDescription

let package = Package(
    name: "Omnicast",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "OmnicastCore", targets: ["OmnicastCore"]),
        .library(name: "OmnicastUI", targets: ["OmnicastUI"]),
        .library(name: "OmnicastExtensions", targets: ["OmnicastExtensions"]),
        .executable(name: "Omnicast", targets: ["Omnicast"])
    ],
    dependencies: [
        .package(url: "https://github.com/soulverteam/SoulverCore", from: "3.4.0")
    ],
    targets: [
        .target(
            name: "OmnicastCore",
            dependencies: [
                .product(name: "SoulverCore", package: "SoulverCore")
            ],
            resources: [.process("Emoji/Resources")]
        ),
        .target(
            name: "OmnicastUI",
            dependencies: ["OmnicastCore"]
        ),
        .target(
            name: "OmnicastExtensions",
            dependencies: ["OmnicastCore"],
            resources: [
                .process("Resources/Licenses"),
                .process("Resources/NodeShim.js"),
                .process("Resources/RaycastShim.js"),
                .process("Resources/react-dom.production.min.js"),
                .process("Resources/react.production.min.js"),
                .copy("Resources/builtin")
            ]
        ),
        .executableTarget(
            name: "Omnicast",
            dependencies: ["OmnicastCore", "OmnicastUI", "OmnicastExtensions"]
        ),
        .testTarget(
            name: "OmnicastCoreTests",
            dependencies: ["OmnicastCore"]
        ),
        .testTarget(
            name: "OmnicastExtensionsTests",
            dependencies: ["OmnicastExtensions"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "OmnicastTests",
            dependencies: ["Omnicast"]
        )
    ],
    swiftLanguageModes: [.v5]
)

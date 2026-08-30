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
    targets: [
        .target(name: "OmnicastCore"),
        .target(
            name: "OmnicastUI",
            dependencies: ["OmnicastCore"]
        ),
        .target(
            name: "OmnicastExtensions",
            dependencies: ["OmnicastCore"],
            resources: [.process("Resources")]
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
        )
    ],
    swiftLanguageModes: [.v5]
)

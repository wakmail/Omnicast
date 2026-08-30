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
        .executable(name: "Omnicast", targets: ["Omnicast"])
    ],
    targets: [
        .target(name: "OmnicastCore"),
        .target(
            name: "OmnicastUI",
            dependencies: ["OmnicastCore"]
        ),
        .executableTarget(
            name: "Omnicast",
            dependencies: ["OmnicastCore", "OmnicastUI"]
        ),
        .testTarget(
            name: "OmnicastCoreTests",
            dependencies: ["OmnicastCore"]
        )
    ],
    swiftLanguageModes: [.v5]
)

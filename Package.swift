// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.
// SPDX-FileCopyrightText: 2026 Iva Horn
// SPDX-License-Identifier: MIT

import PackageDescription

let package = Package(
    name: "Rivers",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
        .tvOS(.v26),
        .visionOS(.v26),
        .watchOS(.v26)
    ],
    products: [
        .executable(
            name: "Example",
            targets: ["Example"]
        ),
        .library(
            name: "Rivers",
            targets: ["Rivers"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "Example",
            dependencies: ["Rivers"]
        ),
        .target(
            name: "Rivers"
        ),
        .testTarget(
            name: "RiversTests",
            dependencies: ["Rivers"]
        ),
    ],
    swiftLanguageModes: [.v6]
)

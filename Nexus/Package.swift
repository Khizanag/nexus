// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Nexus",
    platforms: [
        .iOS(.v26)
    ],
    products: [
        .library(
            name: "Nexus",
            targets: ["Nexus"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/Swinject/Swinject.git", from: "2.9.0")
    ],
    targets: [
        .target(
            name: "Nexus",
            dependencies: ["Swinject"],
            path: "Sources"
        ),
        .testTarget(
            name: "NexusTests",
            dependencies: ["Nexus"],
            path: "Tests"
        )
    ]
)

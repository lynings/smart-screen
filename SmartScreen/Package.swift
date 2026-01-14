// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SmartScreen",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "SmartScreen",
            targets: ["SmartScreen"]
        ),
    ],
    dependencies: [
        // Dependencies will be added here as needed
    ],
    targets: [
        .executableTarget(
            name: "SmartScreen",
            dependencies: [],
            path: "Sources"
        ),
        .testTarget(
            name: "SmartScreenTests",
            dependencies: ["SmartScreen"],
            path: "Tests"
        ),
    ]
)

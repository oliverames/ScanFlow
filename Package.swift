// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PhotoFlow",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .executable(
            name: "PhotoFlow",
            targets: ["PhotoFlow"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "PhotoFlow",
            dependencies: [],
            path: "PhotoFlow",
            exclude: [],
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals"),
            ]
        )
    ]
)

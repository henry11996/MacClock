// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MacClock",
    platforms: [
        .macOS(.v26)
    ],
    targets: [
        .executableTarget(
            name: "MacClock",
            path: "MacClock",
            exclude: ["Assets.xcassets", "Info.plist"]
        ),
    ]
)

// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DoenerShared",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "DoenerShared", targets: ["DoenerShared"]),
    ],
    targets: [
        .target(name: "DoenerShared"),
    ]
)

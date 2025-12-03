// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ToonFormat",
    platforms: [
        .iOS("13.0"),
        .macOS("10.15"),
        .watchOS("6.0"),
        .tvOS("13.0"),
        .visionOS("1.0"),
    ],
    products: [
        .library(
            name: "ToonFormat",
            targets: ["ToonFormat"]
        )
    ],
    targets: [
        .target(
            name: "ToonFormat",
            dependencies: ["TOONEncoder", "TOONDecoder"]
        ),
        .target(
            name: "TOONEncoder"
        ),
        .target(
            name: "TOONDecoder"
        ),
        .testTarget(
            name: "ToonFormatTests",
            dependencies: ["ToonFormat"]
        ),
    ]
)

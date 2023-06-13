// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SwiftSyntaxSupport",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
        .macCatalyst(.v13),
    ],
    products: [
        .library(
            name: "SwiftSyntaxSupport",
            targets: ["SwiftSyntaxSupport"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Swift-Syntax", branch: "main")
    ],
    targets: [
        .target(
            name: "SwiftSyntaxSupport",
            dependencies: [
                .product(name: "SwiftSyntax", package: "Swift-Syntax"),
                .product(name: "SwiftParser", package: "Swift-Syntax"),
            ]
        ),
        .testTarget(
            name: "SwiftSyntaxSupportTests",
            dependencies: ["SwiftSyntaxSupport"]),
    ]
)

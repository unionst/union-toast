// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "union-toast",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "UnionToast",
            targets: ["UnionToast"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/unionst/union-haptics.git", from: "1.0.0"),
        .package(url: "https://github.com/unionst/union-scroll.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "UnionToast",
            dependencies: [
                .product(name: "UnionHaptics", package: "union-haptics"),
                .product(name: "UnionScroll", package: "union-scroll")
            ]
        )
    ]
)

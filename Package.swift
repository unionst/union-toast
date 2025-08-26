// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "union-toast",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "UnionToast",
            targets: ["UnionToast"]
        )
    ],
    dependencies: [
        .package(path: "../union-haptics"),
        .package(path: "../union-scroll")
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

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
        .package(url: "https://github.com/efremidze/Haptica.git", from: "4.0.0"),
        .package(url: "https://github.com/unionst/union-scroll.git", from: "1.0.0"),
        .package(url: "https://github.com/unionst/union-gestures.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "UnionToast",
            dependencies: [
                .product(name: "Haptica", package: "Haptica"),
                .product(name: "UnionScroll", package: "union-scroll"),
                .product(name: "UnionGestures", package: "union-gestures")
            ]
        )
    ]
)

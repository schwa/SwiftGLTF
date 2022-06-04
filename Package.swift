// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GLTF",
    platforms: [
        .iOS("15.0"),
        .macOS("12.0"),
        .macCatalyst("15.0"),
    ],
    products: [
        .library(
            name: "GLTF",
            targets: ["GLTF"]
        ),
    ],
    dependencies: [
        .package(name: "Everything", url: "https://github.com/schwa/Everything", .branch("main")),
        .package(url: "https://github.com/schwa/SIMD-Support", .branch("main")),
    ],
    targets: [
        .target(
            name: "GLTF",
            dependencies: ["Everything", .product(name: "SIMDSupport", package: "SIMD-Support")]
        ),
        .testTarget(
            name: "GLTFTests",
            dependencies: ["GLTF"], resources: [.copy("Box.gltf")]
        ),
    ]
)

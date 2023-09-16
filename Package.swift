// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftGLTF",
    platforms: [
        .iOS("15.0"),
        .macOS("12.0"),
        .macCatalyst("15.0")
    ],
    products: [
        .library(
            name: "SwiftGLTF",
            targets: ["SwiftGLTF"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/schwa/Everything", exact: "0.1.2"),
        .package(url: "https://github.com/schwa/SIMD-Support", exact: "0.2.0"),
    ],
    targets: [
        .target(
            name: "SwiftGLTF",
            dependencies: [
                "Everything",
                .product(name: "SIMDSupport", package: "SIMD-Support")
            ]
        ),
        .testTarget(
            name: "SwiftGLTFTests",
            dependencies: ["SwiftGLTF"],
            resources: [
                .copy("Box.gltf"),
                .copy("Box-byteStride.glb"),
            ]
        ),
    ]
)

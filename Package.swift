// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftGLTF",
    platforms: [
        .iOS("18.0"),
        .macOS("15.0"),
        .macCatalyst("18.0")
    ],
    products: [
        .library(
            name: "SwiftGLTF",
            targets: ["SwiftGLTF"]
        ),
        .executable(
            name: "gltf-render",
            targets: ["gltf-render"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/schwa/GoldenImage.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "SwiftGLTF"
        ),
        .executableTarget(
            name: "gltf-render",
            dependencies: ["SwiftGLTF"]
        ),
        .testTarget(
            name: "SwiftGLTFTests",
            dependencies: ["SwiftGLTF", "GoldenImage"],
            resources: [
                .copy("Box.gltf"),
                .copy("Box-byteStride.glb"),
                .copy("GoldenImages"),
            ]
        ),
    ]
)

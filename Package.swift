// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftGLTF",
    platforms: [
        .iOS("17.0"),
        .macOS("14.0"),
        .macCatalyst("17.0")
    ],
    products: [
        .library(
            name: "SwiftGLTF",
            targets: ["SwiftGLTF"]
        ),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "SwiftGLTF"
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

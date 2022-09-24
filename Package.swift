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
        .executable(name: "SwiftGLTFViewer", targets: ["SwiftGLTFViewer"]),
    ],
    dependencies: [
        .package(url: "https://github.com/schwa/Everything", branch: "main"),
        .package(url: "https://github.com/schwa/SIMD-Support", branch: "main"),
        .package(url: "https://github.com/marmelroy/Zip", from: "2.1.0")
    ],
    targets: [
        .target(
            name: "SwiftGLTF",
            dependencies: ["Everything", .product(name: "SIMDSupport", package: "SIMD-Support")]
        ),
        .executableTarget(
            name: "SwiftGLTFViewer",
            dependencies: ["Everything", "SwiftGLTF", "Zip"],
            resources: [.copy("Box.gltf"), .copy("BarramundiFish.glb")]
        ),
        .testTarget(
            name: "SwiftGLTFTests",
            dependencies: ["SwiftGLTF"],
            resources: [.copy("Box.gltf")]
        ),
    ]
)

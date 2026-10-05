#if os(macOS)
import CoreGraphics
import Foundation
import GoldenImage
import Metal
import RealityKit
import Testing

@testable import SwiftGLTF

struct RealityKitRenderingTests {
    @Test @MainActor
    func generatesEntityFromBox() throws {
        let url = Bundle.module.url(forResource: "Box", withExtension: "gltf")!
        let container = try Container(url: url)
        let root = try RealityKitGLTFGenerator(container: container).generateRootEntity()
        let model = firstModelComponent(root)
        #expect(model != nil)
        #expect(model?.mesh != nil)
    }

    // Verifies issue #7: a Khronos GLB (DamagedHelmet) with interleaved accessors
    // and embedded textures builds an entity without throwing/crashing.
    @Test @MainActor
    func generatesDamagedHelmet() throws {
        let modelsDirectory = repoRoot.appendingPathComponent(".sample-assets/Models")
        let url = modelsDirectory
            .appendingPathComponent("DamagedHelmet")
            .appendingPathComponent("glTF-Binary")
            .appendingPathComponent("DamagedHelmet.glb")
        guard FileManager.default.fileExists(atPath: url.path) else {
            return // sample assets not downloaded; run `just download-sample-assets`
        }
        let container = try Container(url: url)
        let root = try RealityKitGLTFGenerator(container: container).generateRootEntity()
        #expect(firstModelComponent(root) != nil)
    }

    @Test @MainActor
    func rendersBoxMatchingGolden() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return // no Metal device (headless CI)
        }

        let url = Bundle.module.url(forResource: "Box", withExtension: "gltf")!
        let container = try Container(url: url)
        let root = try RealityKitGLTFGenerator(container: container).generateRootEntity()

        let renderer = try RealityRenderer()
        renderer.entities.append(root)

        let light = Entity()
        light.components.set(DirectionalLightComponent(color: .white, intensity: 5000))
        light.look(at: .zero, from: [1, 2, 3], relativeTo: nil)
        renderer.entities.append(light)

        let camera = Entity()
        camera.components.set(PerspectiveCameraComponent())
        camera.look(at: .zero, from: [4, 4, 4], relativeTo: nil)
        renderer.entities.append(camera)
        renderer.activeCamera = camera

        let size = 256
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: size,
            height: size,
            mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead]
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            Issue.record("Could not make target texture")
            return
        }

        let output = try RealityRenderer.CameraOutput(.singleProjection(colorTexture: texture))
        let semaphore = DispatchSemaphore(value: 0)
        try renderer.updateAndRender(
            deltaTime: 0,
            cameraOutput: output,
            onComplete: { _ in semaphore.signal() }
        )
        semaphore.wait()

        guard let cgImage = cgImage(from: texture) else {
            Issue.record("Could not read back texture")
            return
        }

        let goldensDirectory = Bundle.module.url(forResource: "GoldenImages", withExtension: nil)!
        let golden = GoldenImageComparison(
            imageDirectory: goldensDirectory,
            options: .ignoreEdgeAAHalos,
            psnrThreshold: 30.0
        )
        #expect(try golden.image(image: cgImage, matchesGoldenImageNamed: "Box-realitykit"))
    }
}

private var repoRoot: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

private func firstModelComponent(_ entity: Entity) -> ModelComponent? {
    if let model = entity.components[ModelComponent.self] {
        return model
    }
    for child in entity.children {
        if let model = firstModelComponent(child) {
            return model
        }
    }
    return nil
}

private func cgImage(from texture: MTLTexture) -> CGImage? {
    let width = texture.width
    let height = texture.height
    let bytesPerRow = width * 4
    var data = [UInt8](repeating: 0, count: bytesPerRow * height)
    texture.getBytes(
        &data,
        bytesPerRow: bytesPerRow,
        from: MTLRegionMake2D(0, 0, width, height),
        mipmapLevel: 0
    )
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    guard let context = CGContext(
        data: &data,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: bitmapInfo.rawValue
    ) else {
        return nil
    }
    return context.makeImage()
}
#endif

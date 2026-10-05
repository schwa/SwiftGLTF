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

    // A mesh with multiple primitives must produce one material per primitive.
    @Test @MainActor
    func multiPrimitiveMeshKeepsAllPrimitives() throws {
        let url = repoRoot
            .appendingPathComponent(".sample-assets/Models/PointLightIntensityTest/glTF-Binary/PointLightIntensityTest.glb")
        guard FileManager.default.fileExists(atPath: url.path) else {
            return // run `just download-sample-assets`
        }
        let container = try Container(url: url)
        let root = try RealityKitGLTFGenerator(container: container).generateRootEntity()

        var maxMaterials = 0
        func walk(_ entity: Entity) {
            if let model = entity.components[ModelComponent.self] {
                maxMaterials = max(maxMaterials, model.materials.count)
            }
            entity.children.forEach(walk)
        }
        walk(root)
        // PointLightIntensityTest's mesh 0 has 2 primitives.
        #expect(maxMaterials >= 2)
    }

    @Test @MainActor
    func rendersBoxMatchingGolden() async throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return // no Metal device (headless CI)
        }

        let url = Bundle.module.url(forResource: "Box", withExtension: "gltf")!
        let container = try Container(url: url)
        let root = try RealityKitGLTFGenerator(container: container).generateRootEntity()
        try await renderAndCompare(root: root, device: device, from: [4, 4, 4], goldenNamed: "Box-realitykit")
    }

    // Renders a full-PBR GLB (normal/metallic-roughness/occlusion/emissive maps).
    @Test @MainActor
    func rendersDamagedHelmetMatchingGolden() async throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return
        }
        let url = repoRoot
            .appendingPathComponent(".sample-assets/Models/DamagedHelmet/glTF-Binary/DamagedHelmet.glb")
        guard FileManager.default.fileExists(atPath: url.path) else {
            return // run `just download-sample-assets`
        }
        let container = try Container(url: url)
        let root = try RealityKitGLTFGenerator(container: container).generateRootEntity()
        try await renderAndCompare(root: root, device: device, from: [0, 0, 4], goldenNamed: "DamagedHelmet-realitykit")
    }

    // RealityRenderer writes linear color; the readback must encode it as sRGB.
    // A 0.12 gray background reads back as ~3-7/255 with a linear (rgba8Unorm)
    // target. With sRGB encoding it is ~41 (not exactly 31; RealityKit appears to
    // tone-map its output), so assert the encoded range rather than an exact value.
    @Test @MainActor
    func readbackIsSRGBEncoded() async throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return
        }
        let image = try await render(root: Entity(), device: device, from: [0, 0, 4], background: CGColor(gray: 0.12, alpha: 1))
        let pixel = TestSupport.firstPixel(of: image, space: CGColorSpace(name: CGColorSpace.sRGB)!)
        #expect((25 ... 55).contains(Int(pixel[0])), "background red channel \(pixel[0]); ~3-7 means linear readback")
    }

    @MainActor
    private func renderAndCompare(root: Entity, device: MTLDevice, from cameraPosition: SIMD3<Float>, goldenNamed name: String) async throws {
        let cgImage = try await render(root: root, device: device, from: cameraPosition)
        let goldensDirectory = Bundle.module.url(forResource: "GoldenImages", withExtension: nil)!
        let golden = GoldenImageComparison(
            imageDirectory: goldensDirectory,
            options: .ignoreEdgeAAHalos,
            psnrThreshold: 30.0
        )
        #expect(try golden.image(image: cgImage, matchesGoldenImageNamed: name))
    }

    @MainActor
    private func render(root: Entity, device: MTLDevice, from cameraPosition: SIMD3<Float>, background: CGColor? = nil) async throws -> CGImage {
        let renderer = try RealityRenderer()
        if let background {
            renderer.cameraSettings.colorBackground = .color(background)
        }
        renderer.entities.append(root)

        let light = Entity()
        light.components.set(DirectionalLightComponent(color: .white, intensity: 5000))
        light.look(at: .zero, from: [1, 2, 3], relativeTo: nil)
        renderer.entities.append(light)

        let camera = Entity()
        camera.components.set(PerspectiveCameraComponent())
        camera.look(at: .zero, from: cameraPosition, relativeTo: nil)
        renderer.entities.append(camera)
        renderer.activeCamera = camera

        let size = 256
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm_srgb, // RealityRenderer writes linear color
            width: size,
            height: size,
            mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead]
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw GLTFError.unsupported("Could not create a \(size)x\(size) render target")
        }

        let output = try RealityRenderer.CameraOutput(.singleProjection(colorTexture: texture))
        // Await the GPU completion instead of blocking the main actor (same as #56).
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            do {
                try renderer.updateAndRender(deltaTime: 0, cameraOutput: output) { @Sendable _ in
                    continuation.resume()
                }
            }
            catch {
                continuation.resume(throwing: error) // nothing scheduled; onComplete won't fire
            }
        }

        guard let cgImage = cgImage(from: texture) else {
            throw GLTFError.unsupported("Could not read back the render target")
        }
        return cgImage
    }
}

private var repoRoot: URL {
    TestSupport.repositoryRoot
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

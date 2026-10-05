#if os(macOS)
import CoreGraphics
import Foundation
import GoldenImage
import SceneKit
import Testing

@testable import SwiftGLTF

struct SceneKitRenderingTests {
    // Generation alone (no GPU) covers most of the SceneKit generator code.
    @Test
    func generatesSCNSceneFromBox() throws {
        let url = Bundle.module.url(forResource: "Box", withExtension: "gltf")!
        let container = try Container(url: url)
        let generator = SceneKitGenerator(rootURL: url, document: container.document)
        let scene = try generator.generateSCNScene()
        #expect(scene.rootNode.childNodes.isEmpty == false)
    }

    // Renders the generated scene and compares it against a committed golden.
    @Test
    func rendersBoxMatchingGolden() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            // No Metal device (headless CI without GPU): skip rendering.
            return
        }

        let url = Bundle.module.url(forResource: "Box", withExtension: "gltf")!
        let container = try Container(url: url)
        let scene = try SceneKitGenerator(rootURL: url, document: container.document).generateSCNScene()
        try renderAndCompare(scene: scene, device: device, goldenNamed: "Box-scenekit")
    }

    // Renders an embedded, textured model (base-color + metallic-roughness +
    // normal + emissive maps), exercising texture loading and channel splitting.
    @Test
    func rendersDamagedHelmetMatchingGolden() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return
        }
        let url = sampleAssetsModels
            .appendingPathComponent("DamagedHelmet")
            .appendingPathComponent("glTF-Embedded")
            .appendingPathComponent("DamagedHelmet.gltf")
        guard FileManager.default.fileExists(atPath: url.path) else {
            return // run `just download-sample-assets`
        }
        let container = try Container(url: url)
        let scene = try SceneKitGenerator(rootURL: url, document: container.document).generateSCNScene()
        try renderAndCompare(scene: scene, device: device, goldenNamed: "DamagedHelmet-scenekit")
    }

    private var sampleAssetsModels: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(".sample-assets/Models")
    }

    private func renderAndCompare(scene: SCNScene, device: MTLDevice, goldenNamed name: String) throws {
        // Frame the camera from the scene's bounding sphere.
        let (center, radius) = scene.rootNode.boundingSphere
        let distance = CGFloat(radius) * 3 + 1
        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.position = SCNVector3(
            CGFloat(center.x) + distance,
            CGFloat(center.y) + distance,
            CGFloat(center.z) + distance
        )
        camera.look(at: center)
        scene.rootNode.addChildNode(camera)

        let light = SCNNode()
        light.light = SCNLight()
        light.light?.type = .omni
        light.position = camera.position
        scene.rootNode.addChildNode(light)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 300
        scene.rootNode.addChildNode(ambient)

        // PBR materials need an environment to reflect, otherwise they render black.
        scene.lightingEnvironment.contents = CGColor(gray: 1, alpha: 1)
        scene.lightingEnvironment.intensity = 2
        scene.background.contents = CGColor(gray: 0.15, alpha: 1)

        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = scene
        renderer.pointOfView = camera
        let size = CGSize(width: 256, height: 256)
        let image = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .none)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            Issue.record("Could not get CGImage from render")
            return
        }

        let goldensDirectory = Bundle.module.url(forResource: "GoldenImages", withExtension: nil)!
        let golden = GoldenImageComparison(
            imageDirectory: goldensDirectory,
            options: .ignoreEdgeAAHalos,
            psnrThreshold: 30.0
        )
        #expect(try golden.image(image: cgImage, matchesGoldenImageNamed: name))
    }
}
#endif

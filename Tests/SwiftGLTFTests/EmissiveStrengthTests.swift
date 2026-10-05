#if os(macOS)
import Foundation
import RealityKit
import SceneKit
import Testing

@testable import SwiftGLTF

struct EmissiveStrengthTests {
    private func model() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(".sample-assets/Models/EmissiveStrengthTest/glTF-Binary/EmissiveStrengthTest.glb")
    }

    @Test
    func decodesEmissiveStrength() throws {
        let url = model()
        guard FileManager.default.fileExists(atPath: url.path) else {
            return // run `just download-sample-assets`
        }
        let document = try Container(url: url).document
        // Material 0 is "Emit4" with emissiveStrength 4.
        #expect(document.materials[0].emissiveStrength == 4)
        #expect(document.materials[4].emissiveStrength == 8)
        // A material without the extension defaults to 1.
        #expect(document.materials.contains { $0.emissiveStrength == 1 })
    }

    @Test
    func sceneKitAppliesEmissionIntensity() throws {
        let url = model()
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        let container = try Container(url: url)
        let generator = SceneKitGenerator(container: container)
        let material = try generator.generateSCNMaterial(from: container.document.materials[0])
        #expect(material.emission.intensity == 4)
    }

    @Test @MainActor
    func realityKitAppliesEmissiveIntensity() throws {
        let url = model()
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        let container = try Container(url: url)
        let generator = RealityKitGLTFGenerator(container: container)
        let material = try generator.makeMaterial(from: container.document.materials[0]) as? PhysicallyBasedMaterial
        #expect(material?.emissiveIntensity == 4)
    }
}
#endif

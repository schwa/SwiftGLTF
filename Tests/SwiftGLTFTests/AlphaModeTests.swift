#if os(macOS)
import Foundation
import RealityKit
import SceneKit
import Testing

@testable import SwiftGLTF

struct AlphaModeTests {
    private let json = """
    {
      "asset": { "version": "2.0" },
      "materials": [
        { "name": "opaque" },
        { "name": "mask", "alphaMode": "MASK", "alphaCutoff": 0.25, "doubleSided": true },
        { "name": "blend", "alphaMode": "BLEND" }
      ]
    }
    """

    private func document() throws -> Document {
        try JSONDecoder().decode(Document.self, from: Data(json.utf8))
    }

    @Test
    func decodesAlphaModeEnum() throws {
        let materials = try document().materials
        #expect(materials[0].alphaMode == nil) // defaults to OPAQUE at use site
        #expect(materials[1].alphaMode == .MASK)
        #expect(materials[1].alphaCutoff == 0.25)
        #expect(materials[1].doubleSided == true)
        #expect(materials[2].alphaMode == .BLEND)
    }

    @Test
    func sceneKitAppliesAlphaAndCulling() throws {
        let document = try document()
        let generator = SceneKitGenerator(document: document)

        let mask = try generator.generateSCNMaterial(from: document.materials[1])
        #expect(mask.isDoubleSided)
        #expect(!mask.shaderModifiers!.isEmpty) // alpha-clip modifier

        let blend = try generator.generateSCNMaterial(from: document.materials[2])
        #expect(blend.blendMode == .alpha)
        #expect(blend.writesToDepthBuffer == false)
    }

    @Test @MainActor
    func realityKitAppliesAlphaAndCulling() throws {
        let document = try document()
        let generator = RealityKitGLTFGenerator(document: document)

        let mask = try generator.makeMaterial(from: document.materials[1]) as? PhysicallyBasedMaterial
        #expect(mask?.opacityThreshold == 0.25) // MASK -> opacity threshold = alphaCutoff
    }
}
#endif

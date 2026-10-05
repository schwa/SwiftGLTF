#if os(macOS)
import Foundation
import RealityKit
import SceneKit
import Testing

@testable import SwiftGLTF

struct MaterialsUnlitTests {
    private let json = """
    {
      "asset": { "version": "2.0" },
      "materials": [
        { "name": "lit", "pbrMetallicRoughness": { "baseColorFactor": [1, 0, 0, 1] } },
        {
          "name": "unlit",
          "pbrMetallicRoughness": { "baseColorFactor": [0, 1, 0, 1] },
          "extensions": { "KHR_materials_unlit": {} }
        }
      ]
    }
    """

    private func document() throws -> Document {
        try JSONDecoder().decode(Document.self, from: Data(json.utf8))
    }

    @Test
    func decodesUnlitFlag() throws {
        let materials = try document().materials
        #expect(materials[0].isUnlit == false)
        #expect(materials[1].isUnlit == true)
    }

    @Test
    func sceneKitUsesConstantLighting() throws {
        let document = try document()
        let generator = SceneKitGenerator(document: document)
        let lit = try generator.generateSCNMaterial(from: document.materials[0])
        let unlit = try generator.generateSCNMaterial(from: document.materials[1])
        #expect(lit.lightingModel == .physicallyBased)
        #expect(unlit.lightingModel == .constant)
    }

    @Test @MainActor
    func realityKitUsesUnlitMaterial() throws {
        let document = try document()
        let generator = RealityKitGLTFGenerator(document: document)
        #expect(try generator.makeMaterial(from: document.materials[0]) is PhysicallyBasedMaterial)
        #expect(try generator.makeMaterial(from: document.materials[1]) is UnlitMaterial)
    }
}
#endif

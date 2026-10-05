#if os(macOS)
import Foundation
import RealityKit
import SceneKit
import Testing

@testable import SwiftGLTF

struct LightsPunctualTests {
    private let json = """
    {
      "asset": { "version": "2.0" },
      "extensions": {
        "KHR_lights_punctual": {
          "lights": [
            { "type": "directional", "color": [1, 0, 0], "intensity": 2 },
            { "type": "point", "intensity": 3 },
            { "type": "spot", "spot": { "outerConeAngle": 0.5 } }
          ]
        }
      },
      "scene": 0,
      "scenes": [ { "nodes": [0, 1, 2] } ],
      "nodes": [
        { "extensions": { "KHR_lights_punctual": { "light": 0 } } },
        { "extensions": { "KHR_lights_punctual": { "light": 1 } } },
        { "extensions": { "KHR_lights_punctual": { "light": 2 } } }
      ]
    }
    """

    private func document() throws -> Document {
        try JSONDecoder().decode(Document.self, from: Data(json.utf8))
    }

    @Test
    func decodesPunctualLights() throws {
        let lights = try document().punctualLights
        #expect(lights.count == 3)
        #expect(lights[0].type == .directional)
        #expect(lights[0].color == [1, 0, 0])
        #expect(lights[2].spot?.outerConeAngle == 0.5)
    }

    @Test
    func sceneKitEmitsLights() throws {
        let scene = try SceneKitGenerator(document: try document()).generateSCNScene()
        var types: [SCNLight.LightType] = []
        scene.rootNode.enumerateHierarchy { node, _ in
            if let light = node.light {
                types.append(light.type)
            }
        }
        #expect(types.sorted(by: { $0.rawValue < $1.rawValue })
            == [SCNLight.LightType.directional, .omni, .spot].sorted(by: { $0.rawValue < $1.rawValue }))
    }

    @Test @MainActor
    func realityKitEmitsLights() throws {
        let root = try RealityKitGLTFGenerator(document: try document()).generateRootEntity()
        var hasDirectional = false
        var hasPoint = false
        var hasSpot = false
        func walk(_ entity: Entity) {
            if entity.components[DirectionalLightComponent.self] != nil { hasDirectional = true }
            if entity.components[PointLightComponent.self] != nil { hasPoint = true }
            if entity.components[SpotLightComponent.self] != nil { hasSpot = true }
            entity.children.forEach(walk)
        }
        walk(root)
        #expect(hasDirectional)
        #expect(hasPoint)
        #expect(hasSpot)
    }
}
#endif

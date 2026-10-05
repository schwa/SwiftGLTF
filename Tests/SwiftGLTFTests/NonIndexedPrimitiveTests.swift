#if os(macOS)
import Foundation
import RealityKit
import SceneKit
import Testing

@testable import SwiftGLTF

// Primitives without `indices` draw their vertices in order (#49).
struct NonIndexedPrimitiveTests {
    private func container() throws -> Container {
        let positions: [Float] = [0, 0, 0, 1, 0, 0, 0, 1, 0]
        let data = TestSupport.bytes(positions)
        return try TestSupport.container(json: """
        { "asset": { "version": "2.0" },
          "buffers": [ { "byteLength": 36, "uri": "\(TestSupport.dataURI(data))" } ],
          "bufferViews": [ { "buffer": 0, "byteLength": 36 } ],
          "accessors": [ { "bufferView": 0, "componentType": 5126, "count": 3, "type": "VEC3" } ],
          "meshes": [ { "primitives": [ { "attributes": { "POSITION": 0 } } ] } ],
          "nodes": [ { "mesh": 0 } ], "scenes": [ { "nodes": [0] } ], "scene": 0 }
        """)
    }

    @Test
    func sceneKitBuildsATriangleElement() throws {
        let scene = try SceneKitGenerator(container: container()).generateSCNScene()
        var elements: [SCNGeometryElement] = []
        scene.rootNode.enumerateHierarchy { node, _ in
            elements += node.geometry?.elements ?? []
        }
        #expect(elements.count == 1)
        #expect(elements.first?.primitiveType == .triangles)
        #expect(elements.first?.primitiveCount == 1)
    }

    @Test @MainActor
    func realityKitBuildsAMesh() throws {
        let root = try RealityKitGLTFGenerator(container: container()).generateRootEntity()
        var models: [ModelComponent] = []
        func walk(_ entity: Entity) {
            if let model = entity.components[ModelComponent.self] {
                models.append(model)
            }
            entity.children.forEach(walk)
        }
        walk(root)
        #expect(models.count == 1)
    }
}
#endif

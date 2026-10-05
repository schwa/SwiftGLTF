#if os(macOS)
import Foundation
import SceneKit
import simd
import Testing

@testable import SwiftGLTF

struct NodeRotationTests {
    // glTF node.rotation is a quaternion [x, y, z, w]: here 90° about X.
    @Test
    func sceneKitTreatsRotationAsQuaternion() throws {
        let json = """
        {
          "asset": { "version": "2.0" },
          "scene": 0,
          "scenes": [ { "nodes": [0] } ],
          "nodes": [ { "rotation": [0.70710677, 0, 0, 0.70710677] } ]
        }
        """
        let document = try JSONDecoder().decode(Document.self, from: Data(json.utf8))
        let scene = try SceneKitGenerator(document: document).generateSCNScene()
        let node = try #require(scene.rootNode.childNodes.first)

        let expected = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        let actual = node.simdOrientation
        // q and -q are the same rotation.
        #expect(abs(simd_dot(actual.vector, expected.vector)) > 0.999)
    }
}
#endif

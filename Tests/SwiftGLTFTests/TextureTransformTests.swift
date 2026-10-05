import Foundation
import SceneKit
import simd
import Testing

@testable import SwiftGLTF

struct TextureTransformTests {
    // TextureInfo carrying KHR_texture_transform.
    private let json = """
    {
      "index": 0,
      "extensions": {
        "KHR_texture_transform": {
          "offset": [0.25, 0.5],
          "rotation": 0.0,
          "scale": [2.0, 3.0]
        }
      }
    }
    """

    @Test
    func decodesTextureTransform() throws {
        let info = try JSONDecoder().decode(TextureInfo.self, from: Data(json.utf8))
        let transform = try #require(info.textureTransform)
        #expect(transform.offset == [0.25, 0.5])
        #expect(transform.scale == [2.0, 3.0])
        #expect(transform.rotation == 0)
    }

    @Test
    func buildsSceneKitContentsTransform() throws {
        let info = try JSONDecoder().decode(TextureInfo.self, from: Data(json.utf8))
        let transform = try #require(info.textureTransform)
        let matrix = SCNMatrix4(textureTransform: transform)
        // No rotation: scale on the diagonal, offset in the translation row.
        #expect(matrix.m11 == 2)
        #expect(matrix.m22 == 3)
        #expect(matrix.m41 == 0.25)
        #expect(matrix.m42 == 0.5)
    }
}

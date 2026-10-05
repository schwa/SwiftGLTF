#if os(macOS)
import CoreGraphics
import Foundation
import SceneKit
import Testing

@testable import SwiftGLTF

struct SceneKitEmissiveFactorTests {
    // 1x1 opaque white PNG as a data URI.
    private func whitePNGDataURI() -> String {
        TestSupport.dataURI(TestSupport.png(), mimeType: "image/png")
    }

    // glTF emissive = emissiveFactor * emissiveTexture.
    @Test
    func emissiveFactorTintsTexture() throws {
        let json = """
        {
          "asset": { "version": "2.0" },
          "images": [ { "uri": "\(whitePNGDataURI())" } ],
          "textures": [ { "source": 0 } ],
          "materials": [ { "emissiveFactor": [1, 0, 0], "emissiveTexture": { "index": 0 } } ]
        }
        """
        let document = try JSONDecoder().decode(Document.self, from: Data(json.utf8))
        let material = try SceneKitGenerator(document: document).generateSCNMaterial(from: document.materials[0])
        let contents = material.emission.contents as! CGImage

        let pixel = TestSupport.firstPixel(of: contents)
        #expect(pixel[0] > 240) // red kept
        #expect(pixel[1] < 15) // green removed by factor
        #expect(pixel[2] < 15) // blue removed by factor
    }
}
#endif

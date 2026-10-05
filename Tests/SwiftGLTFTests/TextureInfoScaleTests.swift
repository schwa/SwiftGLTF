#if os(macOS)
import Foundation
import SceneKit
import Testing

@testable import SwiftGLTF

struct TextureInfoScaleTests {
    private let json = """
    {
      "asset": { "version": "2.0" },
      "materials": [ {
        "normalTexture": { "index": 0, "scale": 0.5 },
        "occlusionTexture": { "index": 0, "strength": 0.3 },
        "emissiveTexture": { "index": 0 }
      } ]
    }
    """

    private func document() throws -> Document {
        try JSONDecoder().decode(Document.self, from: Data(json.utf8))
    }

    @Test
    func decodesScaleAndStrength() throws {
        let material = try document().materials[0]
        #expect(material.normalTexture?.scale == 0.5)
        #expect(material.occlusionTexture?.strength == 0.3)
        #expect(material.normalTexture?.normalScale == 0.5)
        #expect(material.emissiveTexture?.scale == nil) // only written when present
        #expect(material.occlusionTexture?.occlusionStrength == 0.3)
    }

    @Test
    func defaultsAreOne() throws {
        let info = try JSONDecoder().decode(TextureInfo.self, from: Data(#"{ "index": 0 }"#.utf8))
        #expect(info.normalScale == 1)
        #expect(info.occlusionStrength == 1)
    }

    @Test
    func roundTripsThroughEncoder() throws {
        let document = try document()
        let reloaded = try JSONDecoder().decode(Document.self, from: document.jsonData())
        #expect(reloaded.materials[0].normalTexture?.scale == 0.5)
        #expect(reloaded.materials[0].occlusionTexture?.strength == 0.3)
        let encoded = try JSONSerialization.jsonObject(with: document.jsonData()) as! [String: Any]
        let emissive = ((encoded["materials"] as! [[String: Any]])[0]["emissiveTexture"] as! [String: Any])
        #expect(emissive["scale"] == nil && emissive["strength"] == nil)
    }

    // Occlusion strength s maps ao -> 1 + s * (ao - 1): s = 0 removes occlusion.
    @Test
    func occlusionStrengthBakesTowardWhite() throws {
        // Opaque black (an empty context is transparent, and premultiplied
        // alpha 0 would cancel the bias).
        let context = try #require(CGContext(
            data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        let black = try #require(context.makeImage())
        let baked = try black.occlusionAdjusted(strength: 0)
        let pixel = try #require(baked.dataProvider?.data as Data?)
        #expect(pixel[0] > 250) // red channel now ~white

        // Normal scale 0 flattens xy to the neutral 0.5 (128); z is untouched.
        let flat = try black.normalScaled(by: 0)
        let normal = try #require(flat.dataProvider?.data as Data?)
        #expect(abs(Int(normal[0]) - 128) <= 1)
        #expect(abs(Int(normal[1]) - 128) <= 1)
        #expect(normal[2] < 3)
    }
}
#endif

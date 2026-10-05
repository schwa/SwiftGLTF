#if os(macOS)
import CoreGraphics
import Foundation
import ImageIO
import SceneKit
import Testing
import UniformTypeIdentifiers

@testable import SwiftGLTF

struct SceneKitEmissiveFactorTests {
    // 1x1 opaque white PNG as a data URI.
    private func whitePNGDataURI() throws -> String {
        let context = try #require(CGContext(
            data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
        return "data:image/png;base64,\((data as Data).base64EncodedString())"
    }

    // glTF emissive = emissiveFactor * emissiveTexture.
    @Test
    func emissiveFactorTintsTexture() throws {
        let json = """
        {
          "asset": { "version": "2.0" },
          "images": [ { "uri": "\(try whitePNGDataURI())" } ],
          "textures": [ { "source": 0 } ],
          "materials": [ { "emissiveFactor": [1, 0, 0], "emissiveTexture": { "index": 0 } } ]
        }
        """
        let document = try JSONDecoder().decode(Document.self, from: Data(json.utf8))
        let material = try SceneKitGenerator(document: document).generateSCNMaterial(from: document.materials[0])
        let contents = material.emission.contents as! CGImage

        // Read the pixel back as RGBA8.
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = try #require(CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(contents, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        #expect(pixel[0] > 240) // red kept
        #expect(pixel[1] < 15) // green removed by factor
        #expect(pixel[2] < 15) // blue removed by factor
    }
}
#endif

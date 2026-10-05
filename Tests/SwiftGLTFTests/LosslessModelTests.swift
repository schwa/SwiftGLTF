import Foundation
import Testing

@testable import SwiftGLTF

// Every extensible type must preserve unknown extensions and extras (#33).
struct LosslessModelTests {
    private static let ext = #""extensions": { "VENDOR_x": { "v": 1 } }, "extras": { "tag": "t" }"#

    private let json = """
    {
      "asset": { "version": "2.0", \(ext) },
      "buffers": [ { "byteLength": 4, \(ext) } ],
      "bufferViews": [ { "buffer": 0, "byteLength": 4, \(ext) } ],
      "accessors": [ { "bufferView": 0, "componentType": 5126, "count": 1, "type": "SCALAR", \(ext) } ],
      "cameras": [ { "type": "perspective", "perspective": { "yfov": 1, "znear": 0.1 }, \(ext) } ],
      "images": [ { "uri": "a.png", "mimeType": "image/png", \(ext) } ],
      "samplers": [ { \(ext) } ],
      "textures": [ { "source": 0, \(ext) } ],
      "meshes": [ { "primitives": [ { "attributes": { "POSITION": 0 } } ], \(ext) } ]
    }
    """

    private func preserved(_ object: some Extensible) -> Bool {
        object.extensions?["VENDOR_x"] == .object(["v": .number(1)])
            && object.extras == .object(["tag": .string("t")])
    }

    @Test
    func allTypesPreserveExtensionsAndExtras() throws {
        let document = try JSONDecoder().decode(Document.self, from: Data(json.utf8))
        #expect(preserved(document.asset))
        #expect(preserved(document.buffers[0]))
        #expect(preserved(document.bufferViews[0]))
        #expect(preserved(document.accessors[0]))
        #expect(preserved(document.cameras[0]))
        #expect(preserved(document.images[0]))
        #expect(preserved(document.samplers[0]))
        #expect(preserved(document.textures[0]))
        #expect(preserved(document.meshes[0]))
    }

    @Test
    func imageMimeTypeDecodes() throws {
        let document = try JSONDecoder().decode(Document.self, from: Data(json.utf8))
        #expect(document.images[0].mimeType == "image/png")
    }
}

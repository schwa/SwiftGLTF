import Foundation
import Testing

@testable import SwiftGLTF

// Nested glTF objects must keep extensions/extras through decode and write (#40).
struct SubObjectExtensionsTests {
    private static let ext = #""extensions": { "VENDOR_x": { "v": 1 } }, "extras": { "tag": "t" }"#
    private static let expectedExtensions = Extensions(["VENDOR_x": .object(["v": .number(1)])])
    private static let expectedExtras = JSONValue.object(["tag": .string("t")])

    private let json = """
    {
      "asset": { "version": "2.0" },
      "buffers": [ { "byteLength": 16 } ],
      "bufferViews": [ { "buffer": 0, "byteLength": 16 } ],
      "accessors": [ {
        "componentType": 5126, "count": 2, "type": "SCALAR",
        "sparse": {
          "count": 1,
          "indices": { "bufferView": 0, "componentType": 5125, \(ext) },
          "values": { "bufferView": 0, "byteOffset": 4, \(ext) },
          \(ext)
        }
      } ],
      "cameras": [
        { "type": "perspective", "perspective": { "yfov": 1, "znear": 0.1, \(ext) } },
        { "type": "orthographic", "orthographic": { "xmag": 1, "ymag": 1, "zfar": 10, "znear": 0.1, \(ext) } }
      ],
      "nodes": [ {} ],
      "animations": [ {
        "channels": [ { "sampler": 0, "target": { "node": 0, "path": "translation", \(ext) }, \(ext) } ],
        "samplers": [ { "input": 0, "output": 0, \(ext) } ]
      } ]
    }
    """

    private func check(_ document: Document, _ label: String) {
        let sparse = document.accessors[0].sparse
        let objects: [(String, Extensions?, JSONValue?)] = [
            ("sparse", sparse?.extensions, sparse?.extras),
            ("sparse.indices", sparse?.indices.extensions, sparse?.indices.extras),
            ("sparse.values", sparse?.values.extensions, sparse?.values.extras),
            ("perspective", document.cameras[0].perspective?.extensions, document.cameras[0].perspective?.extras),
            ("orthographic", document.cameras[1].orthographic?.extensions, document.cameras[1].orthographic?.extras),
            ("channel", document.animations[0].channels[0].extensions, document.animations[0].channels[0].extras),
            ("channel.target", document.animations[0].channels[0].target.extensions, document.animations[0].channels[0].target.extras),
            ("animation.sampler", document.animations[0].samplers[0].extensions, document.animations[0].samplers[0].extras)
        ]
        for (name, extensions, extras) in objects {
            #expect(extensions == Self.expectedExtensions, "\(label): \(name) extensions")
            #expect(extras == Self.expectedExtras, "\(label): \(name) extras")
        }
    }

    @Test
    func preservedOnDecodeAndWrite() throws {
        let document = try JSONDecoder().decode(Document.self, from: Data(json.utf8))
        check(document, "decode")
        let reloaded = try JSONDecoder().decode(Document.self, from: document.jsonData())
        check(reloaded, "round trip")
        #expect(reloaded == document)
    }
}

#if os(macOS)
import Foundation
import Testing

@testable import SwiftGLTF

// The RealityKit generator must read non-float attributes correctly (#48).
struct RealityKitAttributeReadingTests {
    private func container() throws -> Container {
        // UNSIGNED_SHORT VEC3 positions, 4-byte aligned (stride 8).
        let positions: [UInt16] = [1, 2, 3, 0, 4, 5, 6, 0, 7, 8, 9, 0]
        // Normalized UNSIGNED_BYTE VEC2 texcoords, 4-byte aligned (stride 4).
        let texcoords: [UInt8] = [0, 255, 0, 0, 255, 0, 0, 0, 51, 102, 0, 0]
        var bytes = positions.withUnsafeBufferPointer { Data(buffer: $0) }
        bytes += Data(texcoords)
        let json = """
        {
          "asset": { "version": "2.0" },
          "buffers": [ { "byteLength": \(bytes.count), "uri": "data:application/octet-stream;base64,\(bytes.base64EncodedString())" } ],
          "bufferViews": [
            { "buffer": 0, "byteLength": 24, "byteStride": 8 },
            { "buffer": 0, "byteOffset": 24, "byteLength": 12, "byteStride": 4 }
          ],
          "accessors": [
            { "bufferView": 0, "componentType": 5123, "count": 3, "type": "VEC3" },
            { "bufferView": 1, "componentType": 5121, "normalized": true, "count": 3, "type": "VEC2" }
          ],
          "meshes": [ { "primitives": [ { "attributes": { "POSITION": 0, "TEXCOORD_0": 1 } } ] } ]
        }
        """
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("rk-attr-\(UUID().uuidString).gltf")
        try Data(json.utf8).write(to: url)
        return try Container(url: url)
    }

    @Test
    func unsignedShortPositionsAreConverted() throws {
        let container = try container()
        let primitive = container.document.meshes[0].primitives[0]
        let positions = try #require(try primitive.value(semantic: .POSITION, type: SIMD3<Float>.self, in: container))
        #expect(positions == [[1, 2, 3], [4, 5, 6], [7, 8, 9]])
    }

    @Test
    func normalizedUnsignedByteTexcoordsAreScaled() throws {
        let container = try container()
        let primitive = container.document.meshes[0].primitives[0]
        let texcoords = try #require(try primitive.value(semantic: .TEXCOORD_0, type: SIMD2<Float>.self, in: container))
        #expect(texcoords == [[0, 1], [1, 0], [0.2, 0.4]])
    }
}
#endif

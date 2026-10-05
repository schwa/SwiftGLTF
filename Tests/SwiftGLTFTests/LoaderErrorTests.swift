import Foundation
import Testing

@testable import SwiftGLTF

// Malformed input must throw a GLTFError, never crash.
struct LoaderErrorTests {
    private func uint32(_ value: UInt32) -> Data {
        withUnsafeBytes(of: value.littleEndian) { Data($0) }
    }

    private func loadGLB(_ data: Data) throws -> GLB {
        let url = try TestSupport.temporaryDirectory().appendingPathComponent("test.glb")
        try data.write(to: url)
        return try GLB(url: url)
    }

    private func isMalformed(_ error: any Error) -> Bool {
        if case GLTFError.malformedGLB = error {
            return true
        }
        return false
    }

    @Test
    func truncatedGLBHeaderThrows() {
        #expect(performing: { _ = try loadGLB(Data([0x67, 0x6C, 0x54, 0x46, 2, 0])) }, throws: isMalformed)
    }

    @Test
    func truncatedGLBBodyThrows() {
        // Header claims 100 bytes; only the header is present.
        let data = uint32(0x4654_6C67) + uint32(2) + uint32(100)
        #expect(performing: { _ = try loadGLB(data) }, throws: isMalformed)
    }

    @Test
    func truncatedChunkHeaderThrows() {
        let data = uint32(0x4654_6C67) + uint32(2) + uint32(16) + uint32(8)
        #expect(performing: { _ = try loadGLB(data) }, throws: isMalformed)
    }

    @Test
    func truncatedChunkContentThrows() {
        // Chunk says 64 bytes of content but the body ends after 4.
        let body = uint32(64) + uint32(0x4E4F_534A) + Data("{}  ".utf8)
        let data = uint32(0x4654_6C67) + uint32(2) + uint32(UInt32(12 + body.count)) + body
        #expect(performing: { _ = try loadGLB(data) }, throws: isMalformed)
    }

    // The spec says unknown chunk types must be ignored, not rejected.
    @Test
    func unknownChunkTypeIsKept() throws {
        let json = Data(#"{"asset":{"version":"2.0"}}  "#.utf8) // padded to 4
        let unknown = uint32(4) + uint32(0x1234_5678) + Data([1, 2, 3, 4])
        let body = uint32(UInt32(json.count)) + uint32(0x4E4F_534A) + json + unknown
        let glb = try loadGLB(uint32(0x4654_6C67) + uint32(2) + uint32(UInt32(12 + body.count)) + body)
        #expect(glb.chunks.count == 2)
        #expect(glb.chunks[1].chunkType == .other(0x1234_5678))
        #expect(glb.chunks[1].chunkType.rawValue == 0x1234_5678)
        // An unknown chunk is not the BIN chunk.
        #expect(throws: GLTFError.self) {
            _ = try glb.binaryBuffer()
        }
    }

    @Test
    func binaryBufferFindsBINChunk() throws {
        let json = Data(#"{"asset":{"version":"2.0"}}  "#.utf8)
        let glbData = GLTFWriter.glbData(json: json, binary: Data([5, 6, 7, 8]))
        let glb = try loadGLB(glbData)
        #expect(try glb.binaryBuffer() == Data([5, 6, 7, 8]))
        let container = try Container(url: {
            let url = try TestSupport.temporaryDirectory().appendingPathComponent("bin.glb")
            try glbData.write(to: url)
            return url
        }())
        #expect(try container.resolve(chunkIndex: 1) == Data([5, 6, 7, 8]))
    }

    // A buffer without a uri in a GLB that has no BIN chunk.
    @Test
    func glbBufferWithoutBINChunkThrows() throws {
        let json = Data(#"{"asset":{"version":"2.0"},"buffers":[{"byteLength":4}]}"#.utf8)
        let url = try TestSupport.temporaryDirectory().appendingPathComponent("nobin.glb")
        try GLTFWriter.glbData(json: json, binary: nil).write(to: url)
        let container = try Container(url: url)
        #expect(throws: GLTFError.self) {
            _ = try container.data(for: container.document.buffers[0])
        }
    }

    @Test
    func glbWithoutChunksThrows() throws {
        // An empty body is rejected at load time.
        let data = uint32(0x4654_6C67) + uint32(2) + uint32(12)
        #expect(performing: { _ = try loadGLB(data) }, throws: isMalformed)
        // And a GLB value without a leading JSON chunk cannot produce a document.
        let header = Header(magic: 0x4654_6C67, version: 2, length: 12)
        #expect(throws: GLTFError.self) {
            _ = try GLB(header: header, chunks: []).document()
        }
    }

    @Test
    func malformedDataURIsThrow() throws {
        for uri in ["data:application/octet-stream;base64", "data:text/plain,hello"] {
            let container = try TestSupport.container(json: """
            { "asset": { "version": "2.0" }, "buffers": [ { "byteLength": 4, "uri": "\(uri)" } ] }
            """)
            #expect(throws: GLTFError.self) {
                _ = try container.data(for: container.document.buffers[0])
            }
        }
    }

    @Test
    func accessorOutsideBufferThrows() throws {
        let buffer = TestSupport.dataURI(Data(count: 12))
        let container = try TestSupport.container(json: """
        { "asset": { "version": "2.0" },
          "buffers": [ { "byteLength": 12, "uri": "\(buffer)" } ],
          "bufferViews": [ { "buffer": 0, "byteLength": 12 }, { "buffer": 0, "byteLength": 12, "byteStride": 8 } ],
          "accessors": [
            { "bufferView": 0, "componentType": 5126, "count": 2, "type": "VEC3" },
            { "bufferView": 1, "componentType": 5126, "count": 2, "type": "VEC3" }
          ] }
        """)
        for accessor in container.document.accessors {
            #expect(throws: GLTFError.self) {
                _ = try container.data(for: accessor)
            }
        }
    }

    // Sparse indices may be UNSIGNED_BYTE, UNSIGNED_SHORT or UNSIGNED_INT.
    @Test(arguments: [(5121, 1), (5125, 4)])
    func sparseIndexComponentTypes(componentType: Int, size: Int) throws {
        let base: [Float] = [0, 0, 0, 0]
        var indices = Data(count: 4)
        indices[0] = 2 // override element 2 (little-endian, first byte)
        let values: [Float] = [9]
        let data = TestSupport.bytes(base) + indices + TestSupport.bytes(values)
        let container = try TestSupport.container(json: """
        { "asset": { "version": "2.0" },
          "buffers": [ { "byteLength": \(data.count), "uri": "\(TestSupport.dataURI(data))" } ],
          "bufferViews": [
            { "buffer": 0, "byteLength": 16 },
            { "buffer": 0, "byteOffset": 16, "byteLength": \(size) },
            { "buffer": 0, "byteOffset": 20, "byteLength": 4 }
          ],
          "accessors": [ { "bufferView": 0, "componentType": 5126, "count": 4, "type": "SCALAR",
            "sparse": { "count": 1, "indices": { "bufferView": 1, "componentType": \(componentType) },
                        "values": { "bufferView": 2 } } } ] }
        """)
        #expect(try container.floatComponents(for: container.document.accessors[0]) == [0, 0, 9, 0])
    }

    @Test
    func resolveHelpers() throws {
        let directory = try TestSupport.temporaryDirectory()
        try Data([7, 8]).write(to: directory.appendingPathComponent("side.bin"))
        let container = try TestSupport.container(json: #"{ "asset": { "version": "2.0" } }"#, in: directory)
        #expect(try container.resolve(path: "side.bin") == Data([7, 8]))
        // resolve(chunkIndex:) is only valid for GLB containers.
        #expect(throws: GLTFError.self) {
            _ = try container.resolve(chunkIndex: 0)
        }
    }

    @Test
    func unsupportedOutputExtensionThrows() throws {
        let container = try TestSupport.container(json: #"{ "asset": { "version": "2.0" } }"#)
        #expect(throws: GLTFError.self) {
            try container.write(to: TestSupport.temporaryDirectory().appendingPathComponent("out.obj"))
        }
    }

    @Test
    func unsupportedInputExtensionThrows() throws {
        let url = try TestSupport.temporaryDirectory().appendingPathComponent("model.obj")
        try Data("{}".utf8).write(to: url)
        #expect(throws: GLTFError.self) {
            _ = try Container(url: url)
        }
    }
}

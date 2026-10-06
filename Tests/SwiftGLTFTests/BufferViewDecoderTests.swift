import Foundation
import Synchronization
import Testing

@testable import SwiftGLTF

/// TEST_decoded_view: a buffer view whose bytes come from a decoder, looked up by `id`.
private struct DecodedViewExtension: GLTFExtension {
    static let extensionName = "TEST_decoded_view"
    let id: Int
}

/// Returns fixed bytes per `id`, counting calls.
private final class FakeViewDecoder: BufferViewDecoder {
    let extensionNames: Set<String> = ["TEST_decoded_view"]
    let payloads: [Int: Data]
    let calls = Mutex(0)

    init(_ payloads: [Int: Data]) {
        self.payloads = payloads
    }

    func data(for bufferView: BufferView, in container: Container) throws -> Data? {
        guard let id = try bufferView.extensionValue(DecodedViewExtension.self)?.id else { return nil }
        calls.withLock { $0 += 1 }
        return payloads[id]
    }
}

/// Buffer 0 is a placeholder with no data (as meshopt's fallback buffers are); views 0-3 are decoded:
/// 0: two VEC3 floats [1...6]; 1: two VEC3 floats interleaved with 4 padding bytes each (byteStride 16);
/// 2: sparse indices [1] (UNSIGNED_BYTE); 3: sparse values [9, 9, 9].
private let json = """
{
  "asset": {"version": "2.0"},
  "extensionsUsed": ["TEST_decoded_view"],
  "buffers": [{"byteLength": 64}],
  "bufferViews": [
    {"buffer": 0, "byteLength": 24, "extensions": {"TEST_decoded_view": {"id": 0}}},
    {"buffer": 0, "byteLength": 32, "byteStride": 16, "extensions": {"TEST_decoded_view": {"id": 1}}},
    {"buffer": 0, "byteLength": 1, "extensions": {"TEST_decoded_view": {"id": 2}}},
    {"buffer": 0, "byteLength": 12, "extensions": {"TEST_decoded_view": {"id": 3}}}
  ],
  "accessors": [
    {"bufferView": 0, "componentType": 5126, "count": 2, "type": "VEC3"},
    {"bufferView": 0, "byteOffset": 12, "componentType": 5126, "count": 1, "type": "VEC3"},
    {"bufferView": 1, "componentType": 5126, "count": 2, "type": "VEC3"},
    {"componentType": 5126, "count": 2, "type": "VEC3", "sparse": {"count": 1,
      "indices": {"bufferView": 2, "componentType": 5121}, "values": {"bufferView": 3}}}
  ]
}
"""

private func floats(_ data: Data) -> [Float] {
    [Float](withUnsafeData: data)
}

private func makeDecoder() -> FakeViewDecoder {
    var interleaved = Data()
    for vertex in [[Float](arrayLiteral: 7, 8, 9), [10, 11, 12]] {
        interleaved.append(TestSupport.bytes(vertex))
        interleaved.append(Data(repeating: 0xEE, count: 4))
    }
    return FakeViewDecoder([
        0: TestSupport.bytes([Float](arrayLiteral: 1, 2, 3, 4, 5, 6)),
        1: interleaved,
        2: Data([1]),
        3: TestSupport.bytes([Float](arrayLiteral: 9, 9, 9)),
    ])
}

struct BufferViewDecoderTests {
    // Accessors read decoded views: whole, at an offset within the view, interleaved, and sparse.
    @Test func accessorsReadDecodedViews() throws {
        let decoder = makeDecoder()
        let container = try TestSupport.container(json: json).withBufferViewDecoders([decoder])
        let accessors = container.document.accessors
        #expect(floats(try container.data(for: accessors[0])) == [1, 2, 3, 4, 5, 6])
        #expect(floats(try container.data(for: accessors[1])) == [4, 5, 6])
        #expect(floats(try container.data(for: accessors[2])) == [7, 8, 9, 10, 11, 12])
        #expect(floats(try container.data(for: accessors[3])) == [0, 0, 0, 9, 9, 9])
        #expect(try container.data(for: container.document.bufferViews[0]) == decoder.payloads[0])
    }

    // Each view is decoded once, however many accessors share it.
    @Test func decodedViewsAreCached() throws {
        let decoder = makeDecoder()
        let container = try TestSupport.container(json: json).withBufferViewDecoders([decoder])
        _ = try container.data(for: container.document.accessors[0])
        _ = try container.data(for: container.document.accessors[1])
        _ = try container.data(for: container.document.bufferViews[0])
        #expect(decoder.calls.withLock { $0 } == 1)
    }

    // A decoder returning bytes of the wrong length is an error, not a silent misread.
    @Test func decodedViewsMustHaveTheViewsLength() throws {
        let decoder = FakeViewDecoder([0: Data(repeating: 0, count: 3)])
        let container = try TestSupport.container(json: json).withBufferViewDecoders([decoder])
        #expect(throws: GLTFError.self) { try container.data(for: container.document.accessors[0]) }
    }

    // Without the decoder the placeholder buffer has no data, so reading fails as before.
    @Test func withoutTheDecoderThePlaceholderBufferFails() throws {
        let container = try TestSupport.container(json: json)
        #expect(throws: GLTFError.self) { try container.data(for: container.document.accessors[0]) }
    }

    // Registered decoders' extensions are listed with the container's supported ones.
    @Test func decodersExtendTheSupportedExtensions() throws {
        let container = try TestSupport.container(json: json).withBufferViewDecoders([makeDecoder()])
        #expect(container.supportedExtensions.contains("TEST_decoded_view"))
        #expect(container.supportedExtensions.isSuperset(of: Document.supportedExtensions))
    }
}

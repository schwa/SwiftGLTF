import Foundation
import SwiftGLTF
import Testing

// GLB output keeps every buffer, with its name, extensions, and extras (#76).
@Test func glbOutputKeepsBufferMetadata() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("glb-buffers-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let first = Data((0 ..< 12).map { UInt8($0) })
    let second = Data((100 ..< 124).map { UInt8($0) })
    let json = """
    {
      "asset": {"version": "2.0"},
      "buffers": [
        {"byteLength": 12, "name": "first", "extras": {"a": 1}, "extensions": {"TEST_x": {"v": 1}},
         "uri": "data:application/octet-stream;base64,\(first.base64EncodedString())"},
        {"byteLength": 24, "name": "second", "extras": {"b": 2},
         "uri": "data:application/octet-stream;base64,\(second.base64EncodedString())"}
      ],
      "bufferViews": [{"buffer": 0, "byteLength": 12}, {"buffer": 1, "byteOffset": 12, "byteLength": 12}],
      "accessors": [
        {"bufferView": 0, "componentType": 5126, "count": 1, "type": "VEC3"},
        {"bufferView": 1, "componentType": 5126, "count": 1, "type": "VEC3"}
      ]
    }
    """
    let source = directory.appendingPathComponent("model.gltf")
    try Data(json.utf8).write(to: source)
    let original = try Container(url: source)
    let output = directory.appendingPathComponent("model.glb")
    try original.write(to: output)

    let written = try Container(url: output)
    let buffers = written.document.buffers
    #expect(buffers.map(\.name) == ["first", "second"])
    #expect(buffers.map(\.extras) == original.document.buffers.map(\.extras))
    #expect(buffers[0].extensions == original.document.buffers[0].extensions)
    #expect(buffers[0].uri == nil)
    #expect(written.document.bufferViews == original.document.bufferViews)
    #expect(try written.data(for: written.document.accessors[0]) == first)
    #expect(try written.data(for: written.document.accessors[1]) == second.subdata(in: 12 ..< 24))
}

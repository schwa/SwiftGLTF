import Foundation
import SwiftGLTF
import Testing

// GLB output must carry images referenced by relative uri (#77).
@Test func glbOutputEmbedsRelativeImages() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("glb-images-\(UUID().uuidString)")
    let sourceDirectory = root.appendingPathComponent("source")
    let outputDirectory = root.appendingPathComponent("output")
    try FileManager.default.createDirectory(at: sourceDirectory.appendingPathComponent("textures"), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let imageBytes = Data((0 ..< 37).map { UInt8($0) })
    try imageBytes.write(to: sourceDirectory.appendingPathComponent("textures/my tex.png"))
    let bufferBytes = Data(repeating: 7, count: 12)
    let json = """
    {
      "asset": {"version": "2.0"},
      "buffers": [{"byteLength": 12, "uri": "data:application/octet-stream;base64,\(bufferBytes.base64EncodedString())"}],
      "bufferViews": [{"buffer": 0, "byteLength": 12}],
      "accessors": [{"bufferView": 0, "componentType": 5126, "count": 1, "type": "VEC3"}],
      "images": [{"uri": "textures/my%20tex.png", "name": "tex"}],
      "textures": [{"source": 0}]
    }
    """
    let source = sourceDirectory.appendingPathComponent("model.gltf")
    try Data(json.utf8).write(to: source)

    let output = outputDirectory.appendingPathComponent("model.glb")
    try Container(url: source).write(to: output)

    let written = try Container(url: output)
    let image = try #require(written.document.images.first)
    #expect(image.uri == nil)
    #expect(image.mimeType == "image/png")
    #expect(image.name == "tex")
    #expect(try written.data(for: image) == imageBytes)
    #expect(try written.data(for: written.document.accessors[0]) == bufferBytes)
    #expect(try !written.validate().contains { $0.severity == .error })
}

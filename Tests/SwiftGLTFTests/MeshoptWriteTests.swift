import Foundation
import SwiftGLTF
import Testing

// Writing an EXT_meshopt_compression model keeps the fallback buffer as a
// data-less placeholder and the extension's buffer references valid (#79).
struct MeshoptWriteTests {
    let compressed = Data((0 ..< 16).map { UInt8($0) })

    // GLB layout produced by gltfpack: buffer 0 is BIN, buffer 1 is the fallback placeholder.
    func makeSource() throws -> Container {
        let json = """
        {
          "asset": {"version": "2.0"},
          "extensionsUsed": ["EXT_meshopt_compression"],
          "extensionsRequired": ["EXT_meshopt_compression"],
          "buffers": [
            {"byteLength": 16},
            {"byteLength": 4000, "extensions": {"EXT_meshopt_compression": {"fallback": true}}}
          ],
          "bufferViews": [
            {"buffer": 1, "byteLength": 4000, "byteStride": 4,
             "extensions": {"EXT_meshopt_compression": {"buffer": 0, "byteLength": 16, "byteStride": 4, "count": 1000, "mode": "ATTRIBUTES"}}}
          ]
        }
        """
        let document = try JSONDecoder().decode(Document.self, from: Data(json.utf8))
        return Container(document: document, binaryBuffer: compressed)
    }

    func check(_ url: URL, source: Container) throws {
        let written = try Container(url: url)
        #expect(written.document.bufferViews == source.document.bufferViews)
        #expect(written.document.buffers.count == 2)
        #expect(written.document.buffers[1].uri == nil)
        #expect(written.document.buffers[1].byteLength == 4000)
        #expect(written.document.buffers[1].extensions == source.document.buffers[1].extensions)
        #expect(try written.data(for: written.document.buffers[0]).prefix(16) == compressed)
        // The placeholder must not be filled with a copy of other data.
        let size = try #require(try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int)
        #expect(size < 4000)
    }

    @Test(arguments: ["glb", "gltf"])
    func writesFallbackAsPlaceholder(pathExtension: String) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("meshopt-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = try makeSource()
        let url = directory.appendingPathComponent("model.\(pathExtension)")
        try source.write(to: url)
        try check(url, source: source)
    }

    @Test func writesExternalGLTFWithoutFallbackSidecar() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("meshopt-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = try makeSource()
        let url = directory.appendingPathComponent("model.gltf")
        try source.write(to: url, embedResources: false)
        try check(url, source: source)
        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
        #expect(files == ["model.bin", "model.gltf"])
    }
}

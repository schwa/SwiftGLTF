import Foundation
import SwiftGLTF
import Testing

// Non-testable import: consumers can wrap an in-memory document and save it (#71).
struct InMemoryContainerTests {
    let document: Document
    let payload = Data([Float](arrayLiteral: 1, 2, 3).withUnsafeBytes { Data($0) })

    init() throws {
        let json = """
        {
          "asset": {"version": "2.0"},
          "buffers": [{"byteLength": 12}],
          "bufferViews": [{"buffer": 0, "byteLength": 12}],
          "accessors": [{"bufferView": 0, "componentType": 5126, "count": 1, "type": "VEC3"}]
        }
        """
        document = try JSONDecoder().decode(Document.self, from: Data(json.utf8))
    }

    func readBack(_ container: Container) throws -> Data {
        try container.data(for: container.document.accessors[0])
    }

    @Test func readsTheBinaryBuffer() throws {
        let container = Container(document: document, binaryBuffer: payload)
        #expect(try readBack(container) == payload)
    }

    @Test(arguments: ["glb", "gltf"])
    func writesAndReloads(pathExtension: String) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("model.\(pathExtension)")
        try Container(document: document, binaryBuffer: payload).write(to: url)
        #expect(try readBack(Container(url: url)) == payload)
    }

    @Test func documentWithoutBuffers() throws {
        let empty = try JSONDecoder().decode(Document.self, from: Data(#"{"asset": {"version": "2.0"}}"#.utf8))
        let container = Container(document: empty)
        #expect(container.document == empty)
    }
}

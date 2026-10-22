import Foundation
import SwiftGLTF
import Testing

// Writing a loaded container with an edited document must write the edits (#73).
struct EditedDocumentWriteTests {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("edited-\(UUID().uuidString)")

    func load(_ json: String) throws -> Container {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("source.gltf")
        try Data(json.utf8).write(to: url)
        return try Container(url: url)
    }

    func writeAndReload(_ container: Container, as pathExtension: String) throws -> Document {
        let url = directory.appendingPathComponent("out.\(pathExtension)")
        try container.write(to: url)
        return try Container(url: url).document
    }

    @Test(arguments: ["gltf", "glb"])
    func addedContentIsWritten(pathExtension: String) throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let container = try load(#"{"asset": {"version": "2.0"}, "scenes": [{"nodes": [0]}], "nodes": [{"name": "a"}]}"#)
        var document = container.document
        document.nodes.append(Node(name: "b", translation: [1, 2, 3]))
        document.nodes[0] = Node(name: "a", children: [Index(1)])
        document.materials.append(Material(name: "m"))
        let written = try writeAndReload(container.withDocument(document), as: pathExtension)
        #expect(written.nodes.map(\.name) == ["a", "b"])
        #expect(written.nodes[0].children == [Index(1)])
        #expect(written.nodes[1].translation == [1, 2, 3])
        #expect(written.materials.map(\.name) == ["m"])
    }

    @Test func removedContentIsNotRestored() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let container = try load("""
        {"asset": {"version": "2.0"}, "extensionsUsed": ["TEST_a"],
         "nodes": [{"name": "a", "extensions": {"TEST_a": {"x": 1}}}, {"name": "b"}]}
        """)
        var document = container.document.removingExtensions(["TEST_a"])
        document.nodes.removeLast()
        let written = try writeAndReload(container.withDocument(document), as: "gltf")
        #expect(written.extensionsUsed.isEmpty)
        #expect(written.nodes.count == 1)
        #expect(written.nodes[0].extensions == nil)
    }

    // Untouched data (here asset extras) survives edits elsewhere.
    @Test func untouchedDataSurvivesEdits() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let container = try load(#"{"asset": {"version": "2.0", "extras": {"custom": 7}}, "nodes": [{"name": "a"}]}"#)
        var document = container.document
        document.nodes.append(Node(name: "b"))
        let url = directory.appendingPathComponent("out.gltf")
        try container.withDocument(document).write(to: url)
        let json = try String(contentsOf: url, encoding: .utf8)
        #expect(json.contains("\"custom\""))
        #expect(json.contains("\"b\""))
    }
}

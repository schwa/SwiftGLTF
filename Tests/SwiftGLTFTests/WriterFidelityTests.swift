import Foundation
import Testing

@testable import SwiftGLTF

// The writer must re-emit exactly the keys the source had (#34).
struct WriterFidelityTests {
    private func temporaryURL(_ name: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("fidelity-\(UUID().uuidString)-\(name)")
    }

    // Top-level JSON of a .gltf or .glb.
    private func json(at url: URL) throws -> JSONValue {
        let data: Data
        if url.pathExtension == "glb" {
            data = try GLB(url: url).chunks[0].content
        }
        else {
            data = try Data(contentsOf: url)
        }
        return try JSONDecoder().decode(JSONValue.self, from: data)
    }

    // Collects paths whose key sets differ. `ignored` are paths the writer rewrites on purpose.
    private func keyMismatches(_ source: JSONValue, _ output: JSONValue, path: String = "", ignored: Set<String>) -> [String] {
        if ignored.contains(path) {
            return []
        }
        switch (source, output) {
        case let (.object(a), .object(b)):
            var problems: [String] = []
            let missing = Set(a.keys).subtracting(b.keys).filter { !ignored.contains("\(path)/\($0)") }
            let extra = Set(b.keys).subtracting(a.keys).filter { !ignored.contains("\(path)/\($0)") }
            if !missing.isEmpty || !extra.isEmpty {
                problems.append("\(path.isEmpty ? "/" : path): missing \(missing.sorted()) extra \(extra.sorted())")
            }
            for key in Set(a.keys).intersection(b.keys) {
                problems += keyMismatches(a[key]!, b[key]!, path: "\(path)/\(key)", ignored: ignored)
            }
            return problems
        case let (.array(a), .array(b)):
            guard a.count == b.count else {
                return ["\(path): array count \(a.count) vs \(b.count)"]
            }
            return zip(a.indices, zip(a, b)).flatMap { index, pair in
                keyMismatches(pair.0, pair.1, path: "\(path)/\(index)", ignored: ignored)
            }
        default:
            return []
        }
    }

    @Test
    func explicitDefaultsAreKeptAndImplicitOnesNotAdded() throws {
        let source = """
        { "asset": { "version": "2.0" },
          "buffers": [ { "byteLength": 12, "uri": "data:application/octet-stream;base64,AAAAAAAAAAAAAAAA" } ],
          "bufferViews": [ { "buffer": 0, "byteLength": 12 } ],
          "accessors": [ { "bufferView": 0, "byteOffset": 0, "normalized": false, "componentType": 5126, "count": 1, "type": "VEC3" } ],
          "meshes": [ { "primitives": [ { "attributes": { "POSITION": 0 }, "mode": 4 } ] } ],
          "nodes": [ { "mesh": 0, "matrix": [1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1] }, { "mesh": 0 } ],
          "materials": [ { "pbrMetallicRoughness": {} } ] }
        """
        let input = temporaryURL("in.gltf")
        try Data(source.utf8).write(to: input)
        let output = temporaryURL("out.gltf")
        try Container(url: input).write(to: output)

        let mismatches = keyMismatches(
            try json(at: input),
            try json(at: output),
            ignored: ["/buffers"] // uri re-embedded by the writer
        )
        #expect(mismatches.isEmpty, "\(mismatches.joined(separator: "\n"))")
    }

    @Test
    func sampleCorpusKeySetsMatchSource() throws {
        let models = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".sample-assets/Models")
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: models.path) else {
            return
        }
        var failures: [String] = []
        var tested = 0
        for name in names.sorted() {
            let directory = models.appendingPathComponent(name).appendingPathComponent("glTF-Binary")
            guard let file = try? FileManager.default.contentsOfDirectory(atPath: directory.path).first(where: { $0.hasSuffix(".glb") }) else {
                continue
            }
            let source = directory.appendingPathComponent(file)
            let size = (try? FileManager.default.attributesOfItem(atPath: source.path)[.size] as? Int) ?? 0
            guard size < 5_000_000, let container = try? Container(url: source) else {
                continue
            }
            let output = temporaryURL("\(name).glb")
            try container.write(to: output)
            defer { try? FileManager.default.removeItem(at: output) }
            // GLB output repacks buffers and rebases bufferViews by design.
            let mismatches = keyMismatches(try json(at: source), try json(at: output), ignored: ["/buffers", "/bufferViews"])
            if !mismatches.isEmpty {
                failures.append("\(name): \(mismatches.prefix(3).joined(separator: "; "))")
            }
            tested += 1
        }
        #expect(tested > 20)
        #expect(failures.isEmpty, "\(failures.joined(separator: "\n"))")
    }
}

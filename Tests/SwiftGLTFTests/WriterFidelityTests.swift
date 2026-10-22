import Foundation
import Testing

@testable import SwiftGLTF

// The writer must not lose data: the output reloads to an equal document, and no
// source key is dropped. Key order, and default values written or omitted, may differ.
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

    // Paths of source keys missing from the output. `ignored` are paths the writer rewrites on purpose.
    private func lostKeys(_ source: JSONValue, _ output: JSONValue, path: String = "", ignored: Set<String>) -> [String] {
        if ignored.contains(path) {
            return []
        }
        switch (source, output) {
        case let (.object(a), .object(b)):
            var lost: [String] = []
            for (key, value) in a {
                let keyPath = "\(path)/\(key)"
                guard !ignored.contains(keyPath) else { continue }
                if let other = b[key] {
                    lost += lostKeys(value, other, path: keyPath, ignored: ignored)
                }
                else if !isDefault(key: key, value: value) {
                    lost.append(keyPath)
                }
            }
            return lost
        case let (.array(a), .array(b)):
            guard a.count == b.count else {
                return ["\(path): array count \(a.count) vs \(b.count)"]
            }
            return zip(a.indices, zip(a, b)).flatMap { index, pair in
                lostKeys(pair.0, pair.1, path: "\(path)/\(index)", ignored: ignored)
            }
        default:
            return []
        }
    }

    // Explicit spec defaults carry no data, so omitting them loses nothing.
    private func isDefault(key: String, value: JSONValue) -> Bool {
        switch (key, value) {
        case ("byteOffset", .number(0)), ("texCoord", .number(0)), ("mode", .number(4)),
             ("normalized", .bool(false)), ("doubleSided", .bool(false)),
             ("alphaMode", .string("OPAQUE")), ("alphaCutoff", .number(0.5)),
             ("metallicFactor", .number(1)), ("roughnessFactor", .number(1)),
             ("scale", .number(1)), ("strength", .number(1)),
             ("wrapS", .number(10497)), ("wrapT", .number(10497)), ("interpolation", .string("LINEAR")):
            return true
        case ("matrix", .array(let values)):
            return values == [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1].map { .number($0) }
        case ("baseColorFactor", .array(let values)):
            return values == [1, 1, 1, 1].map { .number($0) }
        case ("emissiveFactor", .array(let values)):
            return values == [0, 0, 0].map { .number($0) }
        default:
            // An empty array or object carries nothing.
            return value == .array([]) || value == .object([:])
        }
    }

    @Test
    func writtenDocumentKeepsEverything() throws {
        let source = """
        { "asset": { "version": "2.0" },
          "buffers": [ { "byteLength": 12, "uri": "data:application/octet-stream;base64,AAAAAAAAAAAAAAAA" } ],
          "bufferViews": [ { "buffer": 0, "byteLength": 12 } ],
          "accessors": [ { "bufferView": 0, "byteOffset": 0, "normalized": false, "componentType": 5126, "count": 1, "type": "VEC3" } ],
          "meshes": [ { "primitives": [ { "attributes": { "POSITION": 0 }, "mode": 4 } ] } ],
          "nodes": [ { "mesh": 0, "matrix": [1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1] }, { "mesh": 0, "extras": { "a": 1 } } ],
          "materials": [ { "pbrMetallicRoughness": {} } ] }
        """
        let input = temporaryURL("in.gltf")
        try Data(source.utf8).write(to: input)
        let output = temporaryURL("out.gltf")
        let container = try Container(url: input)
        try container.write(to: output)

        #expect(try Container(url: output).document == container.document)
        let lost = lostKeys(try json(at: input), try json(at: output), ignored: ["/buffers"])
        #expect(lost.isEmpty, "\(lost.joined(separator: "\n"))")
    }

    @Test
    func sampleCorpusLosesNothing() throws {
        let models = TestSupport.sampleModels
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
            var problems = lostKeys(try json(at: source), try json(at: output), ignored: [])
            let reloaded = try Container(url: output).document
            if reloaded.nodes != container.document.nodes || reloaded.meshes != container.document.meshes
                || reloaded.materials != container.document.materials || reloaded.accessors != container.document.accessors
                || reloaded.bufferViews != container.document.bufferViews {
                problems.append("reloaded document differs")
            }
            if !problems.isEmpty {
                failures.append("\(name): \(problems.prefix(5).joined(separator: "; "))")
            }
            tested += 1
        }
        #expect(tested > 20)
        #expect(failures.isEmpty, "\(failures.joined(separator: "\n"))")
    }
}

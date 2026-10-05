import Foundation
import Testing

@testable import SwiftGLTF

struct ValidationTests {
    private func issues(_ json: String) throws -> [ValidationIssue] {
        try JSONDecoder().decode(Document.self, from: Data(json.utf8)).validate()
    }

    private func errors(_ json: String) throws -> [ValidationIssue] {
        try issues(json).filter { $0.severity == .error }
    }

    @Test
    func validDocumentHasNoErrors() throws {
        let json = """
        {
          "asset": { "version": "2.0" },
          "buffers": [ { "byteLength": 12 } ],
          "bufferViews": [ { "buffer": 0, "byteLength": 12 } ],
          "accessors": [ { "bufferView": 0, "componentType": 5126, "count": 1, "type": "VEC3" } ],
          "meshes": [ { "primitives": [ { "attributes": { "POSITION": 0 } } ] } ],
          "nodes": [ { "mesh": 0 } ],
          "scenes": [ { "nodes": [0] } ],
          "scene": 0
        }
        """
        #expect(try errors(json).isEmpty)
    }

    @Test
    func outOfRangeIndexIsReported() throws {
        let json = """
        { "asset": { "version": "2.0" }, "nodes": [ { "mesh": 5 } ] }
        """
        #expect(try errors(json).contains { $0.path == "/nodes/0/mesh" })
    }

    @Test
    func accessorOverrunningBufferViewIsReported() throws {
        let json = """
        {
          "asset": { "version": "2.0" },
          "buffers": [ { "byteLength": 12 } ],
          "bufferViews": [ { "buffer": 0, "byteLength": 12 } ],
          "accessors": [ { "bufferView": 0, "componentType": 5126, "count": 2, "type": "VEC3" } ]
        }
        """
        #expect(try errors(json).contains { $0.path == "/accessors/0" })
    }

    @Test
    func bufferViewOverrunningBufferIsReported() throws {
        let json = """
        {
          "asset": { "version": "2.0" },
          "buffers": [ { "byteLength": 8 } ],
          "bufferViews": [ { "buffer": 0, "byteOffset": 4, "byteLength": 8 } ]
        }
        """
        #expect(try errors(json).contains { $0.path == "/bufferViews/0" })
    }

    @Test
    func unsupportedRequiredExtensionIsAnError() throws {
        let json = """
        {
          "asset": { "version": "2.0" },
          "extensionsUsed": ["KHR_draco_mesh_compression"],
          "extensionsRequired": ["KHR_draco_mesh_compression"]
        }
        """
        let all = try issues(json)
        #expect(all.contains { $0.severity == .error && $0.path == "/extensionsRequired" })
        #expect(all.contains { $0.severity == .warning && $0.path == "/extensionsUsed" })
    }

    @Test
    func nodeCycleAndMultipleParentsAreReported() throws {
        let json = """
        {
          "asset": { "version": "2.0" },
          "nodes": [ { "children": [1] }, { "children": [0] }, { "children": [1] } ]
        }
        """
        let found = try errors(json)
        #expect(found.contains { $0.message.contains("cycle") })
        #expect(found.contains { $0.path == "/nodes/1" && $0.message.contains("parents") })
    }

    @Test
    func mismatchedAttributeCountsAreReported() throws {
        let json = """
        {
          "asset": { "version": "2.0" },
          "accessors": [
            { "componentType": 5126, "count": 3, "type": "VEC3" },
            { "componentType": 5126, "count": 4, "type": "VEC3" }
          ],
          "meshes": [ { "primitives": [ { "attributes": { "POSITION": 0, "NORMAL": 1 } } ] } ]
        }
        """
        #expect(try errors(json).contains { $0.path == "/meshes/0/primitives/0/attributes" })
    }

    @Test
    func badSkinAndAnimationReferencesAreReported() throws {
        let json = """
        {
          "asset": { "version": "2.0" },
          "nodes": [ { "skin": 3 } ],
          "skins": [ { "joints": [9] } ],
          "animations": [ {
            "channels": [ { "sampler": 2, "target": { "node": 7, "path": "translation" } } ],
            "samplers": []
          } ]
        }
        """
        let paths = Set(try errors(json).map(\.path))
        #expect(paths.contains("/nodes/0/skin"))
        #expect(paths.contains("/skins/0/joints/0"))
        #expect(paths.contains("/animations/0/channels/0/target/node"))
        #expect(paths.contains("/animations/0/channels/0/sampler"))
    }

    @Test
    func resolveThrowsInsteadOfCrashing() throws {
        let json = #"{ "asset": { "version": "2.0" }, "nodes": [ { "mesh": 5 } ] }"#
        let document = try JSONDecoder().decode(Document.self, from: Data(json.utf8))
        #expect(throws: GLTFError.self) {
            _ = try document.nodes[0].mesh?.resolve(in: document)
        }
    }

    // Every binary sample model should validate without structural errors.
    @Test
    func sampleModelsHaveNoErrors() throws {
        let models = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".sample-assets/Models")
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: models.path) else {
            return // run `just download-sample-assets`
        }
        var failures: [String] = []
        for name in names {
            let dir = models.appendingPathComponent(name).appendingPathComponent("glTF-Binary")
            guard let file = try? FileManager.default.contentsOfDirectory(atPath: dir.path).first(where: { $0.hasSuffix(".glb") }),
                  let container = try? Container(url: dir.appendingPathComponent(file)) else {
                continue
            }
            let errors = container.document.validate().filter { $0.severity == .error }
                // Unsupported required extensions are legitimately reported.
                .filter { $0.path != "/extensionsRequired" }
            if !errors.isEmpty {
                failures.append("\(name): \(errors.map(\.description).joined(separator: "; "))")
            }
        }
        #expect(failures.isEmpty, "\(failures.joined(separator: "\n"))")
    }
}

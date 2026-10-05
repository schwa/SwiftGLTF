import Foundation
import Testing

@testable import SwiftGLTF

struct WriterTests {
    private var models: URL {
        TestSupport.sampleModels
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("writer-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // Model equality ignoring buffer layout (repacking legitimately changes it).
    private func expectEquivalent(_ original: Container, _ reloaded: Container, compareImageURIs: Bool, _ name: String) throws {
        let a = original.document
        let b = reloaded.document
        #expect(a.accessors == b.accessors, "\(name): accessors")
        #expect(a.animations == b.animations, "\(name): animations")
        #expect(a.asset == b.asset, "\(name): asset")
        #expect(a.cameras == b.cameras, "\(name): cameras")
        #expect(a.materials == b.materials, "\(name): materials")
        #expect(a.meshes == b.meshes, "\(name): meshes")
        #expect(a.nodes == b.nodes, "\(name): nodes")
        #expect(a.samplers == b.samplers, "\(name): samplers")
        #expect(a.scene == b.scene && a.scenes == b.scenes, "\(name): scenes")
        #expect(a.skins == b.skins, "\(name): skins")
        #expect(a.textures == b.textures, "\(name): textures")
        #expect(a.extensions == b.extensions && a.extensionsUsed == b.extensionsUsed, "\(name): extensions")
        #expect(a.bufferViews.count == b.bufferViews.count, "\(name): bufferView count")
        if compareImageURIs {
            #expect(a.images == b.images, "\(name): images")
        }
        // Every accessor and image must produce identical bytes.
        for accessor in a.accessors.indices {
            #expect(try original.data(for: a.accessors[accessor]) == reloaded.data(for: b.accessors[accessor]), "\(name): accessor \(accessor) data")
        }
        for image in a.images.indices {
            #expect(try original.data(for: a.images[image]) == reloaded.data(for: b.images[image]), "\(name): image \(image) data")
        }
    }

    @Test
    func encodedJSONIsSpecShaped() throws {
        let json = """
        { "asset": { "version": "2.0" }, "nodes": [ { "mesh": 0, "translation": [1, 2, 3] } ],
          "meshes": [ { "primitives": [ { "attributes": { "POSITION": 0, "_CUSTOM": 0 } } ] } ],
          "accessors": [ { "componentType": 5126, "count": 1, "type": "VEC3" } ] }
        """
        let document = try JSONDecoder().decode(Document.self, from: Data(json.utf8))
        let encoded = try JSONSerialization.jsonObject(with: document.jsonData()) as! [String: Any]
        #expect(encoded["animations"] == nil) // empty arrays omitted
        let node = (encoded["nodes"] as! [[String: Any]])[0]
        #expect(node["mesh"] as? Int == 0) // Index encodes as a plain integer
        #expect(node["matrix"] == nil) // no identity matrix alongside TRS
        let accessor = (encoded["accessors"] as! [[String: Any]])[0]
        #expect(accessor["byteOffset"] == nil) // forbidden without bufferView
        let attributes = ((encoded["meshes"] as! [[String: Any]])[0]["primitives"] as! [[String: Any]])[0]["attributes"] as! [String: Any]
        #expect(attributes["_CUSTOM"] as? Int == 0)
        // And it decodes back to the same model.
        #expect(try JSONDecoder().decode(Document.self, from: document.jsonData()) == document)
    }

    @Test
    func sampleCorpusRoundTrips() throws {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: models.path) else {
            return // run `just download-sample-assets`
        }
        let output = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: output) }
        var tested = 0
        for name in names.sorted() {
            let directory = models.appendingPathComponent(name).appendingPathComponent("glTF-Binary")
            guard let file = try? FileManager.default.contentsOfDirectory(atPath: directory.path).first(where: { $0.hasSuffix(".glb") }) else {
                continue
            }
            let source = directory.appendingPathComponent(file)
            let size = (try? FileManager.default.attributesOfItem(atPath: source.path)[.size] as? Int) ?? 0
            guard size < 5_000_000, let original = try? Container(url: source) else {
                continue
            }
            // GLB -> GLB
            let glb = output.appendingPathComponent("\(name).glb")
            try original.write(to: glb)
            try expectEquivalent(original, Container(url: glb), compareImageURIs: true, "\(name) glb")
            // GLB -> self-contained glTF
            let gltf = output.appendingPathComponent("\(name).gltf")
            try original.write(to: gltf, embedResources: true)
            try expectEquivalent(original, Container(url: gltf), compareImageURIs: false, "\(name) gltf")
            tested += 1
        }
        #expect(tested > 20)
    }

    @Test
    func externalResourcesAreCopiedForNonEmbeddedGLTF() throws {
        let source = models.appendingPathComponent("FlightHelmet/glTF/FlightHelmet.gltf")
        guard FileManager.default.fileExists(atPath: source.path) else {
            return
        }
        let original = try Container(url: source)
        let output = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: output) }
        let destination = output.appendingPathComponent("FlightHelmet.gltf")
        try original.write(to: destination, embedResources: false)
        try expectEquivalent(original, Container(url: destination), compareImageURIs: true, "FlightHelmet")
    }

    @Test
    func glbIsWellFormed() throws {
        let document = try JSONDecoder().decode(Document.self, from: Data(#"{ "asset": { "version": "2.0" } }"#.utf8))
        let glb = GLTFWriter.glbData(json: try document.jsonData(), binary: Data([1, 2, 3]))
        #expect(glb.count.isMultiple(of: 4))
        let magic = glb.prefix(4)
        #expect(magic == Data("glTF".utf8))
        let url = try temporaryDirectory().appendingPathComponent("tiny.glb")
        try glb.write(to: url)
        let reloaded = try GLB(url: url)
        #expect(reloaded.chunks.count == 2)
        #expect(reloaded.chunks[1].content.prefix(3) == Data([1, 2, 3]))
    }
}

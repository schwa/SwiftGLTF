#if os(macOS)
import Foundation
import RealityKit
import SceneKit
import Testing

@testable import SwiftGLTF

// Spec-valid or merely unusual input must not crash (#50).
struct CrashPathTests {
    // 'scenes' is optional; with none there is nothing to show.
    private let noScenes = #"{ "asset": { "version": "2.0" }, "nodes": [ {} ] }"#

    @Test
    func sceneKitWithoutScenesIsEmpty() throws {
        let document = try JSONDecoder().decode(Document.self, from: Data(noScenes.utf8))
        let scene = try SceneKitGenerator(document: document).generateSCNScene()
        #expect(scene.rootNode.childNodes.isEmpty)
    }

    @Test @MainActor
    func realityKitWithoutScenesIsEmpty() throws {
        let document = try JSONDecoder().decode(Document.self, from: Data(noScenes.utf8))
        let root = try RealityKitGLTFGenerator(document: document).generateRootEntity()
        #expect(root.children.isEmpty)
    }

    // A texture without 'source' gets its image from an extension (e.g.
    // KHR_texture_basisu). The material is still built, without that texture.
    private let sourcelessTexture = """
    { "asset": { "version": "2.0" }, "extensionsUsed": ["KHR_texture_basisu"],
      "textures": [ { "extensions": { "KHR_texture_basisu": { "source": 0 } } } ],
      "materials": [ { "pbrMetallicRoughness": { "baseColorTexture": { "index": 0 }, "baseColorFactor": [1, 0, 0, 1] } } ] }
    """

    @Test
    func sceneKitSkipsTextureWithoutSource() throws {
        let document = try JSONDecoder().decode(Document.self, from: Data(sourcelessTexture.utf8))
        let material = try SceneKitGenerator(document: document).generateSCNMaterial(from: document.materials[0])
        // Falls back to the base color factor (SceneKit stores colors as NSColor).
        #expect(material.diffuse.contents is NSColor)
    }

    @Test @MainActor
    func realityKitSkipsTextureWithoutSource() throws {
        let document = try JSONDecoder().decode(Document.self, from: Data(sourcelessTexture.utf8))
        let material = try RealityKitGLTFGenerator(document: document).makeMaterial(from: document.materials[0])
        #expect((material as? PhysicallyBasedMaterial)?.baseColor.texture == nil)
    }

    // An accessor without bufferView is all zeros.
    @Test
    func sceneKitAccessorWithoutBufferViewIsZeros() throws {
        let document = try JSONDecoder().decode(Document.self, from: Data(#"""
        { "asset": { "version": "2.0" },
          "accessors": [ { "componentType": 5126, "count": 3, "type": "VEC3" } ],
          "meshes": [ { "primitives": [ { "attributes": { "POSITION": 0 } } ] } ],
          "nodes": [ { "mesh": 0 } ], "scenes": [ { "nodes": [0] } ] }
        """#.utf8))
        let scene = try SceneKitGenerator(document: document).generateSCNScene()
        let source = try #require(scene.rootNode.childNodes.first?.geometry?.sources(for: .vertex).first)
        #expect(source.vectorCount == 3)
        #expect(source.data.allSatisfy { $0 == 0 })
    }

    // Undecodable image bytes must throw, not crash.
    @Test @MainActor
    func realityKitUndecodableImageThrows() throws {
        let garbage = TestSupport.dataURI(Data([1, 2, 3, 4]), mimeType: "image/png")
        let container = try TestSupport.container(json: """
        { "asset": { "version": "2.0" }, "images": [ { "uri": "\(garbage)" } ], "textures": [ { "source": 0 } ],
          "materials": [ { "pbrMetallicRoughness": { "baseColorTexture": { "index": 0 } } } ] }
        """)
        #expect(throws: GLTFError.self) {
            _ = try RealityKitGLTFGenerator(container: container).makeMaterial(from: container.document.materials[0])
        }
    }

    @Test
    func resolveChunkIndexOutOfRangeThrows() throws {
        let url = try TestSupport.temporaryDirectory().appendingPathComponent("one.glb")
        try GLTFWriter.glbData(json: Data(#"{"asset":{"version":"2.0"}}"#.utf8), binary: nil).write(to: url)
        let container = try Container(url: url)
        #expect(throws: GLTFError.self) {
            _ = try container.resolve(chunkIndex: 5)
        }
    }
}
#endif

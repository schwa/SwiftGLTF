#if os(macOS)
import Foundation
import RealityKit
import SceneKit
import Testing

@testable import SwiftGLTF

struct GeneratorCoverageTests {
    // A one-triangle document; `positions`, `indices`, and extra JSON are configurable.
    private func triangle(
        positionComponentType: Int = 5126,
        positionType: String = "VEC3",
        indexComponentType: Int? = 5123,
        mode: Int = 4,
        extraNodeJSON: String = "",
        materialsJSON: String = "[]",
        materialIndex: Int? = nil
    ) throws -> Container {
        var data = Data()
        let positionBytes: Data
        switch positionComponentType {
        case 5120: positionBytes = Data([0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0]) // BYTE, stride 4
        default: positionBytes = TestSupport.bytes([Float](arrayLiteral: 0, 0, 0, 1, 0, 0, 0, 1, 0))
        }
        data += positionBytes
        let indicesOffset = data.count
        var indexLength = 0
        if let indexComponentType {
            let indexBytes = indexComponentType == 5125 ? TestSupport.bytes([UInt32](arrayLiteral: 0, 1, 2)) : TestSupport.bytes([UInt16](arrayLiteral: 0, 1, 2, 0))
            data += indexBytes
            indexLength = indexComponentType == 5125 ? 12 : 6
        }
        let stride = positionComponentType == 5120 ? #", "byteStride": 4"# : ""
        let indexView = indexComponentType == nil ? "" : #", { "buffer": 0, "byteOffset": \#(indicesOffset), "byteLength": \#(indexLength) }"#
        let indexAccessor = indexComponentType.map { #", { "bufferView": 1, "componentType": \#($0), "count": 3, "type": "SCALAR" }"# } ?? ""
        let indices = indexComponentType == nil ? "" : #", "indices": 1"#
        let material = materialIndex.map { #", "material": \#($0)"# } ?? ""
        return try TestSupport.container(json: """
        { "asset": { "version": "2.0" },
          "buffers": [ { "byteLength": \(data.count), "uri": "\(TestSupport.dataURI(data))" } ],
          "bufferViews": [ { "buffer": 0, "byteLength": \(positionBytes.count)\(stride) }\(indexView) ],
          "accessors": [ { "bufferView": 0, "componentType": \(positionComponentType), "count": 3, "type": "\(positionType)" }\(indexAccessor) ],
          "materials": \(materialsJSON),
          "meshes": [ { "primitives": [ { "attributes": { "POSITION": 0 }\(indices), "mode": \(mode)\(material) } ] } ],
          "nodes": [ { "mesh": 0\(extraNodeJSON) } ], "scenes": [ { "nodes": [0] } ], "scene": 0 }
        """)
    }

    // MARK: - Node transforms

    @Test
    func sceneKitAppliesNodeScale() throws {
        let scene = try SceneKitGenerator(container: triangle(extraNodeJSON: #", "scale": [2, 3, 4]"#)).generateSCNScene()
        #expect(scene.rootNode.childNodes[0].simdScale == [2, 3, 4])
    }

    @Test @MainActor
    func realityKitAppliesNodeScale() throws {
        let root = try RealityKitGLTFGenerator(container: triangle(extraNodeJSON: #", "scale": [2, 3, 4]"#)).generateRootEntity()
        #expect(root.children[0].transform.scale == [2, 3, 4])
    }

    // MARK: - SceneKit geometry variants

    @Test
    func sceneKitHandlesByteVerticesAndUIntIndices() throws {
        let bytes = try SceneKitGenerator(container: triangle(positionComponentType: 5120)).generateSCNScene()
        #expect(bytes.rootNode.childNodes[0].geometry?.sources(for: .vertex).first?.usesFloatComponents == false)
        let uints = try SceneKitGenerator(container: triangle(indexComponentType: 5125)).generateSCNScene()
        #expect(uints.rootNode.childNodes[0].geometry?.elements.first?.bytesPerIndex == 4)
    }

    @Test
    func sceneKitRejectsUnsupportedInput() throws {
        // POINTS with indices.
        #expect(throws: GLTFError.self) {
            _ = try SceneKitGenerator(container: triangle(mode: 0)).generateSCNScene()
        }
        // POSITION declared as SCALAR.
        #expect(throws: GLTFError.self) {
            _ = try SceneKitGenerator(container: triangle(positionType: "SCALAR")).generateSCNScene()
        }
    }

    @Test
    func sceneKitMissingResourcesThrow() throws {
        // Relative buffer URI with no rootURL to resolve against.
        let relative = try JSONDecoder().decode(Document.self, from: Data(#"""
        { "asset": { "version": "2.0" }, "buffers": [ { "byteLength": 4, "uri": "x.bin" } ],
          "bufferViews": [ { "buffer": 0, "byteLength": 4 } ],
          "accessors": [ { "bufferView": 0, "componentType": 5126, "count": 1, "type": "SCALAR" } ],
          "meshes": [ { "primitives": [ { "attributes": { "POSITION": 0 } } ] } ],
          "nodes": [ { "mesh": 0 } ], "scenes": [ { "nodes": [0] } ] }
        """#.utf8))
        #expect(throws: GLTFError.self) {
            _ = try SceneKitGenerator(document: relative).generateSCNScene()
        }
        // uri-less buffer outside a GLB.
        let uriless = try JSONDecoder().decode(Document.self, from: Data(#"""
        { "asset": { "version": "2.0" }, "buffers": [ { "byteLength": 12 } ],
          "bufferViews": [ { "buffer": 0, "byteLength": 12 } ],
          "accessors": [ { "bufferView": 0, "componentType": 5126, "count": 1, "type": "VEC3" } ],
          "meshes": [ { "primitives": [ { "attributes": { "POSITION": 0 } } ] } ],
          "nodes": [ { "mesh": 0 } ], "scenes": [ { "nodes": [0] } ] }
        """#.utf8))
        #expect(throws: GLTFError.self) {
            _ = try SceneKitGenerator(document: uriless).generateSCNScene()
        }
        // Image with neither uri nor bufferView.
        let noSource = try JSONDecoder().decode(Document.self, from: Data(#"""
        { "asset": { "version": "2.0" }, "images": [ {} ], "textures": [ { "source": 0 } ],
          "materials": [ { "pbrMetallicRoughness": { "baseColorTexture": { "index": 0 } } } ] }
        """#.utf8))
        #expect(throws: GLTFError.self) {
            _ = try SceneKitGenerator(document: noSource).generateSCNMaterial(from: noSource.materials[0])
        }
    }

    // MARK: - SceneKit textures

    @Test
    func sceneKitAppliesTextureTransformAndSampler() throws {
        let png = TestSupport.dataURI(TestSupport.png(), mimeType: "image/png")
        let document = try JSONDecoder().decode(Document.self, from: Data("""
        { "asset": { "version": "2.0" },
          "images": [ { "uri": "\(png)" } ],
          "samplers": [ { "magFilter": 9728, "minFilter": 9987, "wrapS": 33071, "wrapT": 33648 } ],
          "textures": [ { "source": 0, "sampler": 0 } ],
          "materials": [ { "pbrMetallicRoughness": { "baseColorTexture": { "index": 0,
            "extensions": { "KHR_texture_transform": { "offset": [0.5, 0], "scale": [2, 2] } } } } } ] }
        """.utf8))
        let material = try SceneKitGenerator(document: document).generateSCNMaterial(from: document.materials[0])
        #expect(material.diffuse.contentsTransform.m41 == 0.5)
        #expect(material.diffuse.contentsTransform.m11 == 2)
        #expect(material.diffuse.wrapS == .clamp)
        #expect(material.diffuse.wrapT == .mirror)
        #expect(material.diffuse.magnificationFilter == .nearest)
        #expect(material.diffuse.minificationFilter == .linear) // mipmap filter falls back
    }

    // MARK: - RealityKit

    @Test @MainActor
    func realityKitIndexComponentTypes() throws {
        for indexType in [5123, 5125] {
            let root = try RealityKitGLTFGenerator(container: triangle(indexComponentType: indexType)).generateRootEntity()
            #expect(root.children[0].components[ModelComponent.self] != nil, "index type \(indexType)")
        }
    }

    @Test @MainActor
    func realityKitDocumentOnlyGeneratorNeedsContainerForMeshes() throws {
        let document = try triangle().document
        #expect(throws: GLTFError.self) {
            _ = try RealityKitGLTFGenerator(document: document).generateRootEntity()
        }
    }

    @Test @MainActor
    func realityKitBlendMaterial() throws {
        let document = try JSONDecoder().decode(Document.self, from: Data(#"""
        { "asset": { "version": "2.0" }, "materials": [ { "alphaMode": "BLEND" } ] }
        """#.utf8))
        let material = try RealityKitGLTFGenerator(document: document).makeMaterial(from: document.materials[0])
        #expect((material as? PhysicallyBasedMaterial)?.blending != .opaque)
    }

    // Real models exercising TANGENT, COLOR_0 and TEXCOORD_1 through RealityKit.
    @Test(arguments: ["VertexColorTest", "MultiUVTest"]) @MainActor
    func realityKitGeneratesSampleWithExtraAttributes(name: String) throws {
        let url = TestSupport.sampleModels.appendingPathComponent("\(name)/glTF-Binary/\(name).glb")
        guard FileManager.default.fileExists(atPath: url.path) else {
            return // run `just download-sample-assets`
        }
        let root = try RealityKitGLTFGenerator(container: Container(url: url)).generateRootEntity()
        #expect(!root.children.isEmpty)
    }
}
#endif

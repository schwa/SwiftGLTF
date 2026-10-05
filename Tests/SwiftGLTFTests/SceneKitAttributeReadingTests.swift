#if os(macOS)
import Foundation
import SceneKit
import Testing

@testable import SwiftGLTF

// SceneKit must read every component type, the normalized flag, and sparse
// accessors (#51).
struct SceneKitAttributeReadingTests {
    // Floats from a source, assuming packed float components.
    private func floats(_ source: SCNGeometrySource) -> [Float] {
        #expect(source.usesFloatComponents && source.bytesPerComponent == 4)
        return source.data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }

    private func sources(_ container: Container) throws -> SCNGeometry {
        let scene = try SceneKitGenerator(container: container).generateSCNScene()
        return try #require(scene.rootNode.childNodes.first?.geometry)
    }

    @Test
    func unsignedShortPositionsAndNormalizedTexcoords() throws {
        let positions: [UInt16] = [1, 2, 3, 0, 4, 5, 6, 0, 7, 8, 9, 0] // stride 8
        let texcoords: [UInt8] = [0, 255, 0, 0, 255, 0, 0, 0, 51, 102, 0, 0] // stride 4
        let data = TestSupport.bytes(positions) + Data(texcoords)
        let container = try TestSupport.container(json: """
        { "asset": { "version": "2.0" },
          "buffers": [ { "byteLength": \(data.count), "uri": "\(TestSupport.dataURI(data))" } ],
          "bufferViews": [
            { "buffer": 0, "byteLength": 24, "byteStride": 8 },
            { "buffer": 0, "byteOffset": 24, "byteLength": 12, "byteStride": 4 }
          ],
          "accessors": [
            { "bufferView": 0, "componentType": 5123, "count": 3, "type": "VEC3" },
            { "bufferView": 1, "componentType": 5121, "normalized": true, "count": 3, "type": "VEC2" }
          ],
          "meshes": [ { "primitives": [ { "attributes": { "POSITION": 0, "TEXCOORD_0": 1 } } ] } ],
          "nodes": [ { "mesh": 0 } ], "scenes": [ { "nodes": [0] } ] }
        """)
        let geometry = try sources(container)
        #expect(floats(try #require(geometry.sources(for: .vertex).first)) == [1, 2, 3, 4, 5, 6, 7, 8, 9])
        #expect(floats(try #require(geometry.sources(for: .texcoord).first)) == [0, 1, 1, 0, 0.2, 0.4])
    }

    @Test
    func sparsePositionsAreApplied() throws {
        // Base positions all zero; sparse override sets vertex 1 to (5, 6, 7).
        let base = [Float](repeating: 0, count: 9)
        let indices: [UInt16] = [1, 0]
        let values: [Float] = [5, 6, 7]
        let data = TestSupport.bytes(base) + TestSupport.bytes(indices) + TestSupport.bytes(values)
        let container = try TestSupport.container(json: """
        { "asset": { "version": "2.0" },
          "buffers": [ { "byteLength": \(data.count), "uri": "\(TestSupport.dataURI(data))" } ],
          "bufferViews": [
            { "buffer": 0, "byteLength": 36 },
            { "buffer": 0, "byteOffset": 36, "byteLength": 4 },
            { "buffer": 0, "byteOffset": 40, "byteLength": 12 }
          ],
          "accessors": [ { "bufferView": 0, "componentType": 5126, "count": 3, "type": "VEC3",
            "sparse": { "count": 1, "indices": { "bufferView": 1, "componentType": 5123 }, "values": { "bufferView": 2 } } } ],
          "meshes": [ { "primitives": [ { "attributes": { "POSITION": 0 } } ] } ],
          "nodes": [ { "mesh": 0 } ], "scenes": [ { "nodes": [0] } ] }
        """)
        let geometry = try sources(container)
        #expect(floats(try #require(geometry.sources(for: .vertex).first)) == [0, 0, 0, 5, 6, 7, 0, 0, 0])
    }

    // An original fixture: UNSIGNED_SHORT positions with byteStride.
    @Test
    func boxByteStrideGenerates() throws {
        let url = try #require(Bundle.module.url(forResource: "Box-byteStride", withExtension: "glb"))
        let scene = try SceneKitGenerator(container: Container(url: url)).generateSCNScene()
        var vertexSources = 0
        scene.rootNode.enumerateHierarchy { node, _ in
            vertexSources += node.geometry?.sources(for: .vertex).count ?? 0
        }
        #expect(vertexSources > 0)
    }
}
#endif

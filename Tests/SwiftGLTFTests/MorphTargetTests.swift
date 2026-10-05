import Foundation
import Testing

@testable import SwiftGLTF

struct MorphTargetTests {
    // One triangle (3 verts) with one POSITION target that moves every vertex by +1 in y.
    private func container(meshWeights: String = "[0.5]", nodeWeights: String? = nil) throws -> Container {
        let base: [Float] = [0, 0, 0, 1, 0, 0, 0, 1, 0]
        let delta: [Float] = [0, 1, 0, 0, 1, 0, 0, 1, 0]
        let bytes = (base + delta).withUnsafeBufferPointer { Data(buffer: $0) }
        let nodeWeightsJSON = nodeWeights.map { ", \"weights\": \($0)" } ?? ""
        let json = """
        {
          "asset": { "version": "2.0" },
          "buffers": [ { "byteLength": 72, "uri": "data:application/octet-stream;base64,\(bytes.base64EncodedString())" } ],
          "bufferViews": [ { "buffer": 0, "byteLength": 36 }, { "buffer": 0, "byteOffset": 36, "byteLength": 36 } ],
          "accessors": [
            { "bufferView": 0, "componentType": 5126, "count": 3, "type": "VEC3" },
            { "bufferView": 1, "componentType": 5126, "count": 3, "type": "VEC3" }
          ],
          "meshes": [ { "weights": \(meshWeights), "primitives": [ { "attributes": { "POSITION": 0 }, "targets": [ { "POSITION": 1 } ] } ] } ],
          "nodes": [ { "mesh": 0\(nodeWeightsJSON) } ]
        }
        """
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("morph-\(UUID().uuidString).gltf")
        try Data(json.utf8).write(to: url)
        return try Container(url: url)
    }

    @Test
    func decodesTypedTargets() throws {
        let primitive = try container().document.meshes[0].primitives[0]
        #expect(primitive.targets.count == 1)
        #expect(primitive.targets[0][.POSITION]?.index == 1)
    }

    @Test
    func effectiveWeightsPreferNodeOverMesh() throws {
        let fromMesh = try container()
        #expect(try fromMesh.document.nodes[0].morphWeights(in: fromMesh.document) == [0.5])
        let fromNode = try container(nodeWeights: "[0.25]")
        #expect(try fromNode.document.nodes[0].morphWeights(in: fromNode.document) == [0.25])
    }

    @Test
    func morphedPositionsApplyWeightedDeltas() throws {
        let container = try container()
        let primitive = container.document.meshes[0].primitives[0]
        let positions = try #require(try container.morphed(.POSITION, of: primitive, weights: [0.5]))
        #expect(positions == [0, 0.5, 0, 1, 0.5, 0, 0, 1.5, 0])
    }

    @Test
    func validatorFlagsWeightTargetMismatch() throws {
        let container = try container(meshWeights: "[0.5, 0.5]")
        #expect(container.document.validate().contains { $0.path == "/meshes/0/weights" })
    }

    @Test
    func decodesRealMorphSample() throws {
        let url = TestSupport.sampleModels.appendingPathComponent("AnimatedMorphCube/glTF-Binary/AnimatedMorphCube.glb")
        guard FileManager.default.fileExists(atPath: url.path) else {
            return // run `just download-sample-assets`
        }
        let container = try Container(url: url)
        let primitive = try #require(container.document.meshes.first?.primitives.first)
        #expect(primitive.targets.count == 2)
        let weights = Array(repeating: Float(1), count: primitive.targets.count)
        let base = try #require(try container.morphed(.POSITION, of: primitive, weights: [0, 0]))
        let morphed = try #require(try container.morphed(.POSITION, of: primitive, weights: weights))
        #expect(base.count == morphed.count)
        #expect(base != morphed)
    }
}

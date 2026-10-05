import Foundation
import simd
import Testing

@testable import SwiftGLTF

struct SkinTests {
    private var modelURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".sample-assets/Models/RiggedSimple/glTF-Binary/RiggedSimple.glb")
    }

    @Test
    func decodesSkinJointsAndBindMatrices() throws {
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            return // run `just download-sample-assets`
        }
        let container = try Container(url: modelURL)
        let document = container.document
        let skin = try #require(document.skins.first)
        #expect(!skin.joints.isEmpty)

        let matrices = try container.inverseBindMatrices(for: skin)
        #expect(matrices.count == skin.joints.count)
        // Inverse bind matrices are affine: last row is (0, 0, 0, 1).
        for matrix in matrices {
            #expect(abs(matrix[3][3] - 1) < 1e-4)
            #expect(abs(matrix[0][3]) < 1e-4 && abs(matrix[1][3]) < 1e-4 && abs(matrix[2][3]) < 1e-4)
        }

        // A mesh node references the skin.
        let skinnedNode = try #require(document.nodes.first { $0.skin != nil })
        #expect(try skinnedNode.skin?.resolve(in: document) == skin)
    }

    @Test
    func jointsAndWeightsAreConsistent() throws {
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            return
        }
        let container = try Container(url: modelURL)
        let document = container.document
        let skin = try #require(document.skins.first)
        let primitive = try #require(document.meshes.flatMap(\.primitives).first { $0.attributes[.JOINTS_0] != nil })

        let joints = try container.floatComponents(for: try #require(primitive.attributes[.JOINTS_0]).resolve(in: document))
        let weights = try container.floatComponents(for: try #require(primitive.attributes[.WEIGHTS_0]).resolve(in: document))
        #expect(joints.count == weights.count)
        // Joint indices point into skin.joints.
        #expect(joints.allSatisfy { Int($0) < skin.joints.count })
        // Each vertex's 4 weights sum to ~1.
        for vertex in stride(from: 0, to: weights.count, by: 4) {
            let sum = weights[vertex] + weights[vertex + 1] + weights[vertex + 2] + weights[vertex + 3]
            #expect(abs(sum - 1) < 1e-2)
        }
    }
}

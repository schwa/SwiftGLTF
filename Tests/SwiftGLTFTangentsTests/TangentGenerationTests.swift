import Foundation
import simd
import Testing

@testable import SwiftGLTF
@testable import SwiftGLTFTangents

struct TangentGenerationTests {
    private func sampleModel(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(".sample-assets/Models/\(path)")
    }

    // BoxTextured has POSITION/NORMAL/TEXCOORD_0 but no TANGENT.
    @Test
    func generatesUnitTangentsForBoxTextured() throws {
        let url = sampleModel("BoxTextured/glTF-Binary/BoxTextured.glb")
        guard FileManager.default.fileExists(atPath: url.path) else {
            return // run `just download-sample-assets`
        }
        let container = try Container(url: url)
        let primitive = try #require(container.document.meshes.flatMap(\.primitives).first)
        #expect(primitive.attributes[.TANGENT] == nil)

        let generated = try TangentGeneration.generate(for: primitive, in: container)
        let result = try #require(generated)

        // Expanded, unindexed triangle list: multiple of 3, all channels aligned.
        #expect(result.positions.count.isMultiple(of: 3))
        #expect(result.tangents.count == result.positions.count)
        #expect(result.normals.count == result.positions.count)
        #expect(result.texcoords.count == result.positions.count)

        // Tangent xyz should be unit length and w should be ±1.
        for tangent in result.tangents {
            let length = simd_length(SIMD3<Float>(tangent.x, tangent.y, tangent.z))
            #expect(abs(length - 1) < 1e-3)
            #expect(abs(abs(tangent.w) - 1) < 1e-3)
        }
    }

    @Test
    func returnsNilWhenTangentsPresent() throws {
        let url = sampleModel("AnimatedMorphCube/glTF-Binary/AnimatedMorphCube.glb")
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        let container = try Container(url: url)
        let primitive = try #require(container.document.meshes.flatMap(\.primitives).first)
        #expect(primitive.attributes[.TANGENT] != nil)
        #expect(try TangentGeneration.generate(for: primitive, in: container) == nil)
    }
}

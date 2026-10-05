import Foundation
import simd
import Testing

@testable import SwiftGLTF

struct SparseAccessorTests {
    private var modelURL: URL {
        TestSupport.sampleModels.appendingPathComponent("SimpleSparseAccessor/glTF-Embedded/SimpleSparseAccessor.gltf")
    }

    @Test
    func sparseOverridesAreApplied() throws {
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            return // run `just download-sample-assets`
        }
        let container = try Container(url: modelURL)

        // Accessor 1 is a sparse VEC3 FLOAT position accessor (14 verts, 3 overrides).
        let accessor = container.document.accessors[1]
        #expect(accessor.sparse != nil)

        let data = try container.data(for: accessor)
        // Parse as tightly-packed floats (SIMD3<Float> has 16-byte stride, glTF uses 12).
        let floats = [Float](withUnsafeData: data)
        #expect(floats.count == 42) // 14 vec3
        func position(_ index: Int) -> SIMD3<Float> {
            SIMD3<Float>(floats[index * 3], floats[index * 3 + 1], floats[index * 3 + 2])
        }

        // Overridden indices 8, 10, 12 get raised y values; others keep base y = 1.
        #expect(position(8) == SIMD3<Float>(1, 2, 0))
        #expect(position(10) == SIMD3<Float>(3, 3, 0))
        #expect(position(12) == SIMD3<Float>(5, 4, 0))
        #expect(position(9) == SIMD3<Float>(2, 1, 0)) // untouched
    }
}

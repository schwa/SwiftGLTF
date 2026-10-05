import Foundation
import Testing

@testable import SwiftGLTF

struct NormalizedAccessorTests {
    private func sampleModel(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(".sample-assets/Models/\(path)")
    }

    // RecursiveSkeletons' COLOR_0 is a normalized UNSIGNED_BYTE VEC4; values must
    // be scaled into [0, 1] rather than read as raw 0...255 integers.
    @Test
    func normalizedUByteColorsScaleToUnitRange() throws {
        let url = sampleModel("RecursiveSkeletons/glTF-Binary/RecursiveSkeletons.glb")
        guard FileManager.default.fileExists(atPath: url.path) else {
            return // run `just download-sample-assets`
        }
        let container = try Container(url: url)

        let colorAccessor = try #require(container.document.accessors.first { accessor in
            accessor.normalized && accessor.componentType == .UNSIGNED_BYTE && accessor.type == .VEC4
        })

        let floats = try container.floatComponents(for: colorAccessor)
        #expect(floats.count == colorAccessor.count * 4)
        #expect(floats.allSatisfy { $0 >= 0 && $0 <= 1 })
        // A normalized byte of 255 -> 1.0; at least one channel should reach near 1.
        #expect(floats.contains { $0 > 0.99 })
    }

    // Non-normalized float colors pass through unchanged.
    @Test
    func floatColorsArePassedThrough() throws {
        let url = sampleModel("BoxVertexColors/glTF-Embedded/BoxVertexColors.gltf")
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        let container = try Container(url: url)
        let document = container.document
        let primitive = try #require(document.meshes.flatMap(\.primitives).first { $0.attributes[.COLOR_0] != nil })
        let colorAccessor = try #require(primitive.attributes[.COLOR_0]).resolve(in: document)
        #expect(colorAccessor.componentType == .FLOAT)
        let floats = try container.floatComponents(for: colorAccessor)
        #expect(floats.count == colorAccessor.count * colorAccessor.type.componentCount)
        #expect(floats.allSatisfy { $0 >= 0 && $0 <= 1 })
    }
}

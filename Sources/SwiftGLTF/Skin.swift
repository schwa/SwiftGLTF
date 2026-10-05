import Foundation
import simd

// glTF skin data. Renderer-agnostic: generators build SCNSkinner / RealityKit
// skeletons separately.
public struct Skin: Codable, Hashable, Sendable, Resolver, Extensible {
    public static var documentKeyPath: KeyPath<Document, [Self]> { \Document.skins }

    // MAT4 accessor, one matrix per joint. Absent means identity matrices.
    public let inverseBindMatrices: Index<Accessor>?
    // Node used as the skeleton root (optional).
    public let skeleton: Index<Node>?
    // Joint nodes; JOINTS_n vertex values index into this array.
    public let joints: [Index<Node>]
    public let name: String?
    public let extensions: Extensions?
    public let extras: JSONValue?
}

public extension Container {
    // One inverse bind matrix per joint (identity when the accessor is absent).
    func inverseBindMatrices(for skin: Skin) throws -> [simd_float4x4] {
        guard let index = skin.inverseBindMatrices else {
            return Array(repeating: matrix_identity_float4x4, count: skin.joints.count)
        }
        let floats = try floatComponents(for: index.resolve(in: document))
        // glTF matrices are column-major, 16 floats each.
        return stride(from: 0, to: floats.count, by: 16).map { base in
            simd_float4x4(
                SIMD4(floats[base], floats[base + 1], floats[base + 2], floats[base + 3]),
                SIMD4(floats[base + 4], floats[base + 5], floats[base + 6], floats[base + 7]),
                SIMD4(floats[base + 8], floats[base + 9], floats[base + 10], floats[base + 11]),
                SIMD4(floats[base + 12], floats[base + 13], floats[base + 14], floats[base + 15])
            )
        }
    }
}

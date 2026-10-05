import Foundation
import MikkTSpace
import simd
import SwiftGLTF

// Generates per-vertex tangents for a glTF primitive that lacks a TANGENT
// attribute (needed for correct normal mapping), using MikkTSpace.
//
// This is an opt-in module so the core SwiftGLTF target stays free of the
// MikkTSpace C dependency. It operates on the renderer-agnostic model layer and
// returns an EXPANDED (unindexed) triangle list, since MikkTSpace computes a
// tangent per face-vertex.
public enum TangentGeneration {
    public struct Mesh {
        public var positions: [SIMD3<Float>]
        public var normals: [SIMD3<Float>]
        public var texcoords: [SIMD2<Float>]
        public var tangents: [SIMD4<Float>] // xyz + handedness sign in w
    }

    public enum Error: Swift.Error {
        case missingAttributes
        case unsupportedPrimitiveMode
        case mikkTSpaceFailed
    }

    // Returns nil if the primitive already has tangents.
    public static func generate(for primitive: SwiftGLTF.Mesh.Primitive, in container: Container) throws -> Mesh? {
        guard primitive.attributes[.TANGENT] == nil else {
            return nil
        }
        guard primitive.mode == .TRIANGLES else {
            throw Error.unsupportedPrimitiveMode
        }
        guard let positionIndex = primitive.attributes[.POSITION],
              let normalIndex = primitive.attributes[.NORMAL],
              let texcoordIndex = primitive.attributes[.TEXCOORD_0] else {
            throw Error.missingAttributes
        }

        let document = container.document
        let positions = try vec3(container.floatComponents(for: positionIndex.resolve(in: document)))
        let normals = try vec3(container.floatComponents(for: normalIndex.resolve(in: document)))
        let texcoords = try vec2(container.floatComponents(for: texcoordIndex.resolve(in: document)))

        // Expand into an unindexed triangle list.
        let indices: [Int]
        if let indicesIndex = primitive.indices {
            let floats = try container.floatComponents(for: indicesIndex.resolve(in: document))
            indices = floats.map { Int($0) }
        } else {
            indices = Array(0 ..< positions.count)
        }
        guard indices.count.isMultiple(of: 3) else {
            throw Error.unsupportedPrimitiveMode
        }

        let context = MikkContext(
            positions: indices.map { positions[$0] },
            normals: indices.map { normals[$0] },
            texcoords: indices.map { texcoords[$0] }
        )
        guard context.run() else {
            throw Error.mikkTSpaceFailed
        }
        return Mesh(
            positions: context.positions,
            normals: context.normals,
            texcoords: context.texcoords,
            tangents: context.tangents
        )
    }

    private static func vec3(_ floats: [Float]) -> [SIMD3<Float>] {
        stride(from: 0, to: floats.count, by: 3).map {
            SIMD3<Float>(floats[$0], floats[$0 + 1], floats[$0 + 2])
        }
    }

    private static func vec2(_ floats: [Float]) -> [SIMD2<Float>] {
        stride(from: 0, to: floats.count, by: 2).map {
            SIMD2<Float>(floats[$0], floats[$0 + 1])
        }
    }
}

// Holds the expanded per-face-vertex mesh data and the MikkTSpace output.
private final class MikkContext {
    let positions: [SIMD3<Float>]
    let normals: [SIMD3<Float>]
    let texcoords: [SIMD2<Float>]
    var tangents: [SIMD4<Float>]

    init(positions: [SIMD3<Float>], normals: [SIMD3<Float>], texcoords: [SIMD2<Float>]) {
        self.positions = positions
        self.normals = normals
        self.texcoords = texcoords
        self.tangents = Array(repeating: SIMD4<Float>(0, 0, 0, 1), count: positions.count)
    }

    var faceCount: Int { positions.count / 3 }

    func run() -> Bool {
        var interface = SMikkTSpaceInterface()
        interface.m_getNumFaces = { context in
            Int32(object(context).faceCount)
        }
        interface.m_getNumVerticesOfFace = { _, _ in 3 }
        interface.m_getPosition = { context, out, face, vert in
            let position = object(context).positions[Int(face) * 3 + Int(vert)]
            out?[0] = position.x; out?[1] = position.y; out?[2] = position.z
        }
        interface.m_getNormal = { context, out, face, vert in
            let normal = object(context).normals[Int(face) * 3 + Int(vert)]
            out?[0] = normal.x; out?[1] = normal.y; out?[2] = normal.z
        }
        interface.m_getTexCoord = { context, out, face, vert in
            let texcoord = object(context).texcoords[Int(face) * 3 + Int(vert)]
            out?[0] = texcoord.x; out?[1] = texcoord.y
        }
        interface.m_setTSpaceBasic = { context, tangent, sign, face, vert in
            let object = object(context)
            object.tangents[Int(face) * 3 + Int(vert)] = SIMD4<Float>(
                tangent?[0] ?? 0,
                tangent?[1] ?? 0,
                tangent?[2] ?? 0,
                sign
            )
        }

        return withUnsafeMutablePointer(to: &interface) { interfacePointer in
            var mikkContext = SMikkTSpaceContext(
                m_pInterface: interfacePointer,
                m_pUserData: Unmanaged.passUnretained(self).toOpaque()
            )
            return genTangSpaceDefault(&mikkContext) != 0
        }
    }
}

private func object(_ context: UnsafePointer<SMikkTSpaceContext>?) -> MikkContext {
    Unmanaged<MikkContext>.fromOpaque(context!.pointee.m_pUserData).takeUnretainedValue()
}

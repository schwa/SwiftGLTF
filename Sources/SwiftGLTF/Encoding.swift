import Foundation
import simd

// Hand-written encoders for types whose synthesized encoding would produce
// invalid glTF (wrong shape, empty arrays, or spec-forbidden fields).

public extension Index {
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(index)
    }
}

public extension URI {
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(string)
    }
}

// Arrays in glTF must be absent rather than empty.
private extension KeyedEncodingContainer {
    mutating func encodeNonEmpty<T: Encodable>(_ values: [T], forKey key: Key) throws {
        if !values.isEmpty {
            try encode(values, forKey: key)
        }
    }
}

public extension Document {
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeNonEmpty(extensionsUsed, forKey: .extensionsUsed)
        try container.encodeNonEmpty(extensionsRequired, forKey: .extensionsRequired)
        try container.encodeNonEmpty(accessors, forKey: .accessors)
        try container.encodeNonEmpty(animations, forKey: .animations)
        try container.encode(asset, forKey: .asset)
        try container.encodeNonEmpty(buffers, forKey: .buffers)
        try container.encodeNonEmpty(bufferViews, forKey: .bufferViews)
        try container.encodeNonEmpty(cameras, forKey: .cameras)
        try container.encodeNonEmpty(images, forKey: .images)
        try container.encodeNonEmpty(materials, forKey: .materials)
        try container.encodeNonEmpty(meshes, forKey: .meshes)
        try container.encodeNonEmpty(nodes, forKey: .nodes)
        try container.encodeNonEmpty(samplers, forKey: .samplers)
        try container.encodeIfPresent(scene, forKey: .scene)
        try container.encodeNonEmpty(scenes, forKey: .scenes)
        try container.encodeNonEmpty(skins, forKey: .skins)
        try container.encodeNonEmpty(textures, forKey: .textures)
        try container.encodeIfPresent(extensions, forKey: .extensions)
        try container.encodeIfPresent(extras, forKey: .extras)
    }
}

public extension Accessor {
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(bufferView, forKey: .bufferView)
        // byteOffset must not be present without a bufferView; 0 is the default.
        if bufferView != nil, byteOffset != 0 {
            try container.encode(byteOffset, forKey: .byteOffset)
        }
        try container.encode(componentType, forKey: .componentType)
        if normalized {
            try container.encode(normalized, forKey: .normalized)
        }
        try container.encode(count, forKey: .count)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(max, forKey: .max)
        try container.encodeIfPresent(min, forKey: .min)
        try container.encodeIfPresent(sparse, forKey: .sparse)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(extensions, forKey: .extensions)
        try container.encodeIfPresent(extras, forKey: .extras)
    }
}

public extension Mesh {
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(primitives, forKey: .primitives)
        try container.encodeNonEmpty(weights, forKey: .weights)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(extensions, forKey: .extensions)
        try container.encodeIfPresent(extras, forKey: .extras)
    }
}

public extension Mesh.Primitive {
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let stringKeyed = { (map: [Semantic: Index<Accessor>]) in
            Dictionary(uniqueKeysWithValues: map.map { ($0.key.rawValue, $0.value) })
        }
        try container.encode(stringKeyed(attributes), forKey: .attributes)
        try container.encodeIfPresent(indices, forKey: .indices)
        try container.encodeIfPresent(material, forKey: .material)
        if mode != .TRIANGLES {
            try container.encode(mode, forKey: .mode)
        }
        try container.encodeNonEmpty(targets.map(stringKeyed), forKey: .targets)
        try container.encodeIfPresent(extensions, forKey: .extensions)
        try container.encodeIfPresent(extras, forKey: .extras)
    }
}

public extension Node {
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(camera, forKey: .camera)
        try container.encodeNonEmpty(children, forKey: .children)
        try container.encodeIfPresent(skin, forKey: .skin)
        // Decoding fills in identity; only write a real matrix (never alongside TRS defaults).
        if let matrix, matrix != matrix_identity_float4x4 {
            let columns = [matrix.columns.0, matrix.columns.1, matrix.columns.2, matrix.columns.3]
            try container.encode(columns.flatMap { [$0.x, $0.y, $0.z, $0.w] }, forKey: .matrix)
        }
        try container.encodeIfPresent(mesh, forKey: .mesh)
        try container.encodeIfPresent(rotation, forKey: .rotation)
        try container.encodeIfPresent(scale, forKey: .scale)
        try container.encodeIfPresent(translation, forKey: .translation)
        try container.encodeIfPresent(weights, forKey: .weights)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(extensions, forKey: .extensions)
        try container.encodeIfPresent(extras, forKey: .extras)
    }
}

public extension Scene {
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeNonEmpty(nodes, forKey: .nodes)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(extensions, forKey: .extensions)
        try container.encodeIfPresent(extras, forKey: .extras)
    }
}

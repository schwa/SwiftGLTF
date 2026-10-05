import Foundation
import simd

// KHR_texture_transform: an affine transform (offset/rotation/scale) applied to
// a texture's UV coordinates.
// https://github.com/KhronosGroup/glTF/tree/main/extensions/2.0/Khronos/KHR_texture_transform
public struct KHRTextureTransform: GLTFExtension {
    public static let extensionName = "KHR_texture_transform"

    public let offset: SIMD2<Float>
    public let rotation: Float
    public let scale: SIMD2<Float>
    public let texCoord: Int?

    public enum CodingKeys: CodingKey {
        case offset
        case rotation
        case scale
        case texCoord
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        offset = try container.decodeIfPresent(SIMD2<Float>.self, forKey: .offset) ?? [0, 0]
        rotation = try container.decodeIfPresent(Float.self, forKey: .rotation) ?? 0
        scale = try container.decodeIfPresent(SIMD2<Float>.self, forKey: .scale) ?? [1, 1]
        texCoord = try container.decodeIfPresent(Int.self, forKey: .texCoord)
    }
}

public extension TextureInfo {
    var textureTransform: KHRTextureTransform? {
        try? extensionValue(KHRTextureTransform.self)
    }
}

import Foundation
import simd
#if canImport(SceneKit)
import SceneKit
#endif

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

#if canImport(SceneKit)
extension SCNMatrix4 {
    // KHR_texture_transform -> SceneKit texture-coordinate transform.
    // Treats UV as a row vector: uv' = [u, v, 0, 1] * matrix.
    init(textureTransform transform: KHRTextureTransform) {
        let cosR = SCNFloat(cos(transform.rotation))
        let sinR = SCNFloat(sin(transform.rotation))
        let scaleX = SCNFloat(transform.scale.x)
        let scaleY = SCNFloat(transform.scale.y)
        let offsetX = SCNFloat(transform.offset.x)
        let offsetY = SCNFloat(transform.offset.y)
        var matrix = SCNMatrix4Identity
        matrix.m11 = scaleX * cosR
        matrix.m12 = scaleX * sinR
        matrix.m21 = -scaleY * sinR
        matrix.m22 = scaleY * cosR
        matrix.m41 = offsetX
        matrix.m42 = offsetY
        self = matrix
    }
}
#endif

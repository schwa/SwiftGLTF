import Foundation

// KHR_materials_specular: adjusts the strength and color of specular reflection.
// https://github.com/KhronosGroup/glTF/tree/main/extensions/2.0/Khronos/KHR_materials_specular
public struct KHRMaterialsSpecular: GLTFExtension {
    public static let extensionName = "KHR_materials_specular"

    public let specularFactor: Float
    public let specularTexture: TextureInfo?
    public let specularColorFactor: SIMD3<Float>
    public let specularColorTexture: TextureInfo?

    public enum CodingKeys: CodingKey {
        case specularFactor
        case specularTexture
        case specularColorFactor
        case specularColorTexture
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        specularFactor = try container.decodeIfPresent(Float.self, forKey: .specularFactor) ?? 1
        specularTexture = try container.decodeIfPresent(TextureInfo.self, forKey: .specularTexture)
        specularColorFactor = try container.decodeIfPresent(SIMD3<Float>.self, forKey: .specularColorFactor) ?? [1, 1, 1]
        specularColorTexture = try container.decodeIfPresent(TextureInfo.self, forKey: .specularColorTexture)
    }
}

public extension Material {
    var specular: KHRMaterialsSpecular? {
        try? extensionValue(KHRMaterialsSpecular.self)
    }
}

import Foundation

// KHR_materials_volume: gives a transmissive surface a thickness so it behaves
// as a volume with absorption.
// https://github.com/KhronosGroup/glTF/tree/main/extensions/2.0/Khronos/KHR_materials_volume
public struct KHRMaterialsVolume: GLTFExtension {
    public static let extensionName = "KHR_materials_volume"

    public let thicknessFactor: Float
    public let thicknessTexture: TextureInfo?
    public let attenuationDistance: Float
    public let attenuationColor: SIMD3<Float>

    public enum CodingKeys: CodingKey {
        case thicknessFactor
        case thicknessTexture
        case attenuationDistance
        case attenuationColor
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        thicknessFactor = try container.decodeIfPresent(Float.self, forKey: .thicknessFactor) ?? 0
        thicknessTexture = try container.decodeIfPresent(TextureInfo.self, forKey: .thicknessTexture)
        attenuationDistance = try container.decodeIfPresent(Float.self, forKey: .attenuationDistance) ?? .infinity
        attenuationColor = try container.decodeIfPresent(SIMD3<Float>.self, forKey: .attenuationColor) ?? [1, 1, 1]
    }
}

public extension Material {
    var volume: KHRMaterialsVolume? {
        try? extensionValue(KHRMaterialsVolume.self)
    }
}

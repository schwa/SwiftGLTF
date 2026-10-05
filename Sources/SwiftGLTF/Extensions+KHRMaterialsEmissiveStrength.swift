import Foundation

// KHR_materials_emissive_strength: scales a material's emissive output beyond
// the [0,1] range of emissiveFactor.
// https://github.com/KhronosGroup/glTF/tree/main/extensions/2.0/Khronos/KHR_materials_emissive_strength
public struct KHRMaterialsEmissiveStrength: GLTFExtension {
    public static let extensionName = "KHR_materials_emissive_strength"

    public let emissiveStrength: Float

    public enum CodingKeys: CodingKey {
        case emissiveStrength
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        emissiveStrength = try container.decodeIfPresent(Float.self, forKey: .emissiveStrength) ?? 1
    }
}

public extension Material {
    var emissiveStrength: Float {
        (try? extensionValue(KHRMaterialsEmissiveStrength.self))?.emissiveStrength ?? 1
    }
}

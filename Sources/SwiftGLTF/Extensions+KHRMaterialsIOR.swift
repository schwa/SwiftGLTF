import Foundation

// KHR_materials_ior: overrides the default index of refraction (1.5).
// https://github.com/KhronosGroup/glTF/tree/main/extensions/2.0/Khronos/KHR_materials_ior
public struct KHRMaterialsIOR: GLTFExtension {
    public static let extensionName = "KHR_materials_ior"

    public let ior: Float

    public enum CodingKeys: CodingKey {
        case ior
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ior = try container.decodeIfPresent(Float.self, forKey: .ior) ?? 1.5
    }
}

public extension Material {
    var ior: Float {
        (try? extensionValue(KHRMaterialsIOR.self))?.ior ?? 1.5
    }
}

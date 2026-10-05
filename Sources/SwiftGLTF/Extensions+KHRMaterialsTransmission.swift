import Foundation

// KHR_materials_transmission: optically transparent surfaces that transmit light.
// https://github.com/KhronosGroup/glTF/tree/main/extensions/2.0/Khronos/KHR_materials_transmission
public struct KHRMaterialsTransmission: GLTFExtension {
    public static let extensionName = "KHR_materials_transmission"

    public let transmissionFactor: Float
    public let transmissionTexture: TextureInfo?

    public enum CodingKeys: CodingKey {
        case transmissionFactor
        case transmissionTexture
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        transmissionFactor = try container.decodeIfPresent(Float.self, forKey: .transmissionFactor) ?? 0
        transmissionTexture = try container.decodeIfPresent(TextureInfo.self, forKey: .transmissionTexture)
    }
}

public extension Material {
    var transmission: KHRMaterialsTransmission? {
        try? extensionValue(KHRMaterialsTransmission.self)
    }
}

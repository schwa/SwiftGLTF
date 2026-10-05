import Foundation
import simd

// KHR_lights_punctual: punctual (directional/point/spot) lights.
// https://github.com/KhronosGroup/glTF/tree/main/extensions/2.0/Khronos/KHR_lights_punctual

public struct Light: Decodable, Hashable, Sendable {
    public enum LightType: String, Decodable, Hashable, Sendable {
        case directional
        case point
        case spot
    }

    public struct Spot: Decodable, Hashable, Sendable {
        public let innerConeAngle: Float
        public let outerConeAngle: Float

        public enum CodingKeys: CodingKey {
            case innerConeAngle
            case outerConeAngle
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            innerConeAngle = try container.decodeIfPresent(Float.self, forKey: .innerConeAngle) ?? 0
            outerConeAngle = try container.decodeIfPresent(Float.self, forKey: .outerConeAngle) ?? (.pi / 4)
        }
    }

    public let type: LightType
    public let color: SIMD3<Float>
    public let intensity: Float
    public let range: Float?
    public let spot: Spot?
    public let name: String?

    public enum CodingKeys: CodingKey {
        case type
        case color
        case intensity
        case range
        case spot
        case name
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(LightType.self, forKey: .type)
        color = try container.decodeIfPresent(SIMD3<Float>.self, forKey: .color) ?? [1, 1, 1]
        intensity = try container.decodeIfPresent(Float.self, forKey: .intensity) ?? 1
        range = try container.decodeIfPresent(Float.self, forKey: .range)
        spot = try container.decodeIfPresent(Spot.self, forKey: .spot)
        name = try container.decodeIfPresent(String.self, forKey: .name)
    }
}

// Document-level extension: the array of lights.
public struct KHRLightsPunctual: GLTFExtension {
    public static let extensionName = "KHR_lights_punctual"
    public let lights: [Light]
}

// Node-level extension: an index into the document's lights.
public struct KHRLightsPunctualNodeRef: GLTFExtension {
    public static let extensionName = "KHR_lights_punctual"
    public let light: Int
}

public extension Document {
    var punctualLights: [Light] {
        (try? extensionValue(KHRLightsPunctual.self))?.lights ?? []
    }
}

public extension Node {
    func punctualLight(in document: Document) -> Light? {
        guard let ref = try? extensionValue(KHRLightsPunctualNodeRef.self) else {
            return nil
        }
        let lights = document.punctualLights
        guard ref.light >= 0, ref.light < lights.count else {
            return nil
        }
        return lights[ref.light]
    }
}

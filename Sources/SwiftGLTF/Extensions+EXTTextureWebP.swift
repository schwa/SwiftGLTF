import Foundation

// EXT_texture_webp: supplies a WebP image as an alternative texture source.
// https://github.com/KhronosGroup/glTF/tree/main/extensions/2.0/Vendor/EXT_texture_webp
public struct EXTTextureWebP: GLTFExtension {
    public static let extensionName = "EXT_texture_webp"

    public let source: Index<Image>

    public enum CodingKeys: CodingKey {
        case source
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        source = try container.decode(Index<Image>.self, forKey: .source)
    }
}

public extension Texture {
    var webPSource: Index<Image>? {
        (try? extensionValue(EXTTextureWebP.self))?.source
    }
}

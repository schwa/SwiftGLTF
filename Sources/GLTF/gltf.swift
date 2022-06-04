// swiftlint:disable file_length
// swiftlint:disable type_name
// swiftlint:disable fatal_error_message

import Everything
import Foundation
import simd

// https://github.com/KhronosGroup/glTF/tree/master/specification/2.0

public protocol Resolver {
    associatedtype C: RandomAccessCollection where C.Index == Int
    static var documentKeyPath: KeyPath<GLTFDocument, C> { get }
}

public struct Index<R>: Decodable, Hashable where R: Resolver {
    public typealias C = R.C
    public let index: C.Index

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        index = try container.decode(Int.self)
    }

    public func resolve(in document: GLTFDocument) throws -> C.Element {
        let value = document[keyPath: R.documentKeyPath]
        return value[index]
    }
}

extension Index: CustomStringConvertible {
    public var description: String {
        "\(C.Element.self)#\(index)"
    }
}

public struct GLTFDocument: Decodable {
    public let extensionsUsed: [String]
    public let extensionsRequired: [String]
    public let accessors: [GLTFAccessor]
    public let animations: [Animation]
    public let asset: Asset
    public let buffers: [Buffer]
    public let bufferViews: [BufferView]
    public let cameras: [Camera]
    public let images: [Image]
    public let materials: [Material]
    public let meshes: [Mesh]
    public let nodes: [GLTFNode]
    public let samplers: [Sampler]
    public let scene: Index<GLTFScene>?
    public let scenes: [GLTFScene]
    public let skins: [Skin]?
    public let textures: [Texture]
    // let extensions: [String: Any]
    // let extras: Any

    public enum CodingKeys: CodingKey {
        case extensionsUsed
        case extensionsRequired
        case accessors
        case animations
        case asset
        case buffers
        case bufferViews
        case cameras
        case images
        case materials
        case meshes
        case nodes
        case samplers
        case scene
        case scenes
        case skins
        case textures
        case extensions
        case extras
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        extensionsUsed = try container.decodeIfPresent([String].self, forKey: .extensionsUsed) ?? []
        extensionsRequired = try container.decodeIfPresent([String].self, forKey: .extensionsRequired) ?? []
        accessors = try container.decodeIfPresent([GLTFAccessor].self, forKey: .accessors) ?? []
        animations = try container.decodeIfPresent([Animation].self, forKey: .animations) ?? []
        asset = try container.decode(Asset.self, forKey: .asset)
        buffers = try container.decodeIfPresent([Buffer].self, forKey: .buffers) ?? []
        bufferViews = try container.decodeIfPresent([BufferView].self, forKey: .bufferViews) ?? []
        cameras = try container.decodeIfPresent([Camera].self, forKey: .cameras) ?? []
        images = try container.decodeIfPresent([Image].self, forKey: .images) ?? []
        materials = try container.decodeIfPresent([Material].self, forKey: .materials) ?? []
        meshes = try container.decodeIfPresent([Mesh].self, forKey: .meshes) ?? []
        nodes = try container.decodeIfPresent([GLTFNode].self, forKey: .nodes) ?? []
        samplers = try container.decodeIfPresent([Sampler].self, forKey: .samplers) ?? []
        scene = try container.decodeIfPresent(Index<GLTFScene>.self, forKey: .scene)
        scenes = try container.decodeIfPresent([GLTFScene].self, forKey: .scenes) ?? []
        skins = try container.decodeIfPresent([Skin].self, forKey: .skins) ?? []
        textures = try container.decodeIfPresent([Texture].self, forKey: .textures) ?? []
//        extensions = try container.decodeIfPresent([String].self, forKey: .extensions) ?? []
//        extras = try container.decodeIfPresent([String].self, forKey: .extras) ?? []
    }
}

public struct GLTFAccessor: Decodable, Resolver {
    public static let documentKeyPath = \GLTFDocument.accessors

    public let bufferView: Index<BufferView>?
    public let byteOffset: Int
    public enum ComponentType: Int, Decodable {
        case BYTE = 5120
        case UNSIGNED_BYTE = 5121
        case SHORT = 5122
        case UNSIGNED_SHORT = 5123
        case UNSIGNED_INT = 5125
        case FLOAT = 5126
    }

    public let componentType: ComponentType
    public let normalized: Bool
    public let count: Int
    public enum AttributeType: String, Decodable {
        case SCALAR
        case VEC2
        case VEC3
        case VEC4
        case MAT2
        case MAT3
        case MAT4
    }

    public let type: AttributeType
    public let max: [Float]?
    public let min: [Float]?
    // let sparse: Any
    public let name: String?
    // let extensions: [String: Any]
    // let extras: Any

    public enum CodingKeys: CodingKey {
        case bufferView
        case byteOffset
        case componentType
        case normalized
        case count
        case type
        case max
        case min
        case sparse
        case name
        case `extension`
        case extras
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bufferView = try container.decodeIfPresent(Index<BufferView>.self, forKey: .bufferView)
        byteOffset = try container.decodeIfPresent(Int.self, forKey: .byteOffset) ?? 0
        componentType = try container.decode(ComponentType.self, forKey: .componentType)
        normalized = try container.decodeIfPresent(Bool.self, forKey: .normalized) ?? false
        count = try container.decode(Int.self, forKey: .count)
        type = try container.decode(AttributeType.self, forKey: .type)
        max = try container.decodeIfPresent([Float].self, forKey: .max)
        min = try container.decodeIfPresent([Float].self, forKey: .min)
        // sparse
        name = try container.decodeIfPresent(String.self, forKey: .name)
        // extension
        // extras
    }
}

public struct Animation: Decodable {
    public static let documentKeyPath = \GLTFDocument.animations
}

public struct Asset: Decodable {
    public let copyright: String?
    public let generator: String?
    public let version: Version
    public let minVersion: Version?
    // let extensions: [String: Any]?
    // let extras: Any?

    public struct Version: Decodable {
        let string: String

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            string = try container.decode(String.self)
        }
    }
}

public struct Buffer: Decodable, Resolver {
    public static let documentKeyPath = \GLTFDocument.buffers

    public let uri: URI?
    public let byteLength: Int
    public let name: String?
    // let extensions: [String: Any]?
    // let extras: Any?
}

public struct BufferView: Decodable, Resolver {
    public static let documentKeyPath = \GLTFDocument.bufferViews

    public let buffer: Index<Buffer>
    public let byteOffset: Int
    public let byteLength: Int
    public let byteStride: Int?
    public enum Target: Int, Decodable {
        case ARRAY_BUFFER = 34962
        case ELEMENT_ARRAY_BUFFER = 34963
    }

    public let target: Target?
    public let name: String?
    // let extensions: [String: Any]?
    // let extras: Any?

    public enum CodingKeys: CodingKey {
        case buffer
        case byteOffset
        case byteLength
        case byteStride
        case target
        case name
        // extension
        // extras
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        buffer = try container.decode(Index<Buffer>.self, forKey: .buffer)
        byteOffset = try container.decodeIfPresent(Int.self, forKey: .byteOffset) ?? 0
        byteLength = try container.decode(Int.self, forKey: .byteLength)
        byteStride = try container.decodeIfPresent(Int.self, forKey: .byteStride)
        target = try container.decodeIfPresent(Target.self, forKey: .target)
        name = try container.decodeIfPresent(String.self, forKey: .name)
    }
}

public struct Camera: Decodable, Resolver {
    public static let documentKeyPath = \GLTFDocument.cameras
}

public struct Extension: Decodable {
}

public struct Extras: Decodable {
}

public struct Image: Decodable, Resolver {
    public static let documentKeyPath = \GLTFDocument.images

    public let uri: URI?
    public let mimetype: String?
    public let bufferView: Index<BufferView>?
    public let name: String?
    // let extensions: [String: Any]?
    // let extras: Any?
}

public struct Material: Decodable, Resolver {
    public static let documentKeyPath = \GLTFDocument.materials

    public let name: String?
    // let extensions: [String: Any]?
    // let extras: Any?

    public struct PBRMetallicRoughness: Decodable {
        public let baseColorFactor: SIMD4<Float>
        public let baseColorTexture: TextureInfo?
        public let metallicFactor: Float
        public let roughnessFactor: Float
        public let metallicRoughnessTexture: TextureInfo?
        // let extensions: [String: Any]?
        // let extras: Any?

        public enum CodingKeys: CodingKey {
            case baseColorFactor
            case baseColorTexture
            case metallicFactor
            case roughnessFactor
            case metallicRoughnessTexture
            case extensions
            case extras
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            baseColorFactor = try container.decodeIfPresent(SIMD4<Float>.self, forKey: .baseColorFactor) ?? [1, 1, 1, 1]
            baseColorTexture = try container.decodeIfPresent(TextureInfo.self, forKey: .baseColorTexture)
            metallicFactor = try container.decodeIfPresent(Float.self, forKey: .metallicFactor) ?? 1
            roughnessFactor = try container.decodeIfPresent(Float.self, forKey: .roughnessFactor) ?? 1
            metallicRoughnessTexture = try container.decodeIfPresent(TextureInfo.self, forKey: .metallicRoughnessTexture)
        }
    }

    public let pbrMetallicRoughness: PBRMetallicRoughness?
    public let normalTexture: TextureInfo?
    public let occlusionTexture: TextureInfo?
    public let emissiveTexture: TextureInfo?
    public let emissiveFactor: SIMD3<Float>? // [0,0,0]
    public let alphaMode: String?
    public let alphaCutoff: Float? // 0.5
    // swiftlint:disable:next discouraged_optional_boolean
    public let doubleSided: Bool? // false
}

public struct Mesh: Decodable, Resolver {
    public static let documentKeyPath = \GLTFDocument.meshes

    public struct Primitive: Decodable {
        public enum Semantic: String, Decodable {
            case POSITION
            case NORMAL
            case TANGENT
            case TEXCOORD_0
            case TEXCOORD_1
            case TEXCOORD_2
            case COLOR_0
            case JOINTS_0
            case WEIGHTS_0
        }

        public let attributes: [Semantic: Index<GLTFAccessor>]
        public let indices: Index<GLTFAccessor>?
        public let material: Index<Material>?
        public enum Mode: Int, Decodable {
            case POINTS = 0
            case LINES = 1
            case LINE_LOOP = 2
            case LINE_STRIP = 3
            case TRIANGLES = 4
            case TRIANGLE_STRIP = 5
            case TRIANGLE_FAN = 6
        }

        public let mode: Mode
        public let targets: [[String: Int]]
        // let extensions: [String: Any]?
        // let extras: Any?

        public enum CodingKeys: CodingKey {
            case attributes
            case indices
            case material
            case mode
            case targets
            case extensions
            case extras
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            attributes = Dictionary(uniqueKeysWithValues: try container.decode([String: Index<GLTFAccessor>].self, forKey: .attributes).map { (Semantic(rawValue: $0)!, $1) })
            indices = try container.decodeIfPresent(Index<GLTFAccessor>.self, forKey: .indices)
            material = try container.decodeIfPresent(Index<Material>.self, forKey: .material)
            mode = try container.decodeIfPresent(Mode.self, forKey: .mode) ?? .TRIANGLES
            targets = try container.decodeIfPresent([[String: Int]].self, forKey: .targets) ?? []
        }
    }

    public let primitives: [Primitive]
    public let weights: [Float]
    public let name: String?
    // let extensions: [String: Any]?
    // let extras: Any?

    public enum CodingKeys: CodingKey {
        case primitives
        case weights
        case name
        case extensions
        case extras
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        primitives = try container.decode([Primitive].self, forKey: .primitives)
        weights = try container.decodeIfPresent([Float].self, forKey: .weights) ?? []
        name = try container.decodeIfPresent(String.self, forKey: .name)
    }
}

public struct GLTFNode: Decodable, Resolver {
    public static let documentKeyPath = \GLTFDocument.nodes

    public let camera: Index<Camera>?
    public let children: [Index<GLTFNode>]
//    let skin: Int?
    public let matrix: simd_float4x4?
    public let mesh: Index<Mesh>?
    public let rotation: SIMD4<Float>?
    public let scale: SIMD3<Float>?
    public let translation: SIMD3<Float>?
//    let weights: [Int]?
    public let name: String?
    // let extensions: [String: Any]?
    // let extras: Any?

    public enum CodingKeys: CodingKey {
        case camera
        case children
        case skin
        case matrix
        case mesh
        case rotation
        case scale
        case translation
        case weights
        case name
        case extensions
        case extras
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        camera = try container.decodeIfPresent(Index<Camera>.self, forKey: .camera)
        children = try container.decodeIfPresent([Index<GLTFNode>].self, forKey: .children) ?? []
//        skin = try container.decodeIfPresent(XXXX, forKey: .skin)
        matrix = try container.decodeIfPresent(MatrixDecoder.self, forKey: .matrix).map(\.matrix) ?? .identity
        mesh = try container.decodeIfPresent(Index<Mesh>.self, forKey: .mesh)
        rotation = try container.decodeIfPresent(SIMD4<Float>.self, forKey: .rotation)
        scale = try container.decodeIfPresent(SIMD3<Float>.self, forKey: .scale)
        translation = try container.decodeIfPresent(SIMD3<Float>.self, forKey: .translation)
//        weights = try container.decodeIfPresent(XXXX, forKey: .weights)
        name = try container.decodeIfPresent(String.self, forKey: .name)
//        extensions = try container.decodeIfPresent(XXXX, forKey: .XXXX)
//        extras = try container.decodeIfPresent(XXXX, forKey: .XXXX)
    }
}

public struct Sampler: Decodable, Resolver {
    public static let documentKeyPath = \GLTFDocument.samplers

    public enum MagFilter: Int, Decodable {
        case NEAREST = 9728
        case LINEAR = 9729
    }

    public enum MinFilter: Int, Decodable {
        case NEAREST = 9728
        case LINEAR = 9729
        case NEAREST_MIPMAP_NEAREST = 9984
        case LINEAR_MIPMAP_NEAREST = 9985
        case NEAREST_MIPMAP_LINEAR = 9986
        case LINEAR_MIPMAP_LINEAR = 9987
    }

    public enum Wrap: Int, Decodable {
        case CLAMP_TO_EDGE = 33071
        case MIRRORED_REPEAT = 33648
        case REPEAT = 10497
    }

    public let magFilter: MagFilter?
    public let minFilter: MinFilter?
    public let wrapS: Wrap
    public let wrapT: Wrap
    public let name: String??
    // let extensions: [String: Any]?
    // let extras: Any?

    public enum CodingKeys: CodingKey {
        case magFilter
        case minFilter
        case wrapS
        case wrapT
        case name
        case extensions
        case extras
    }

    public init() {
        magFilter = .NEAREST
        minFilter = .NEAREST
        wrapS = .REPEAT
        wrapT = .REPEAT
        name = nil
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        magFilter = try container.decodeIfPresent(MagFilter.self, forKey: .magFilter)
        minFilter = try container.decodeIfPresent(MinFilter.self, forKey: .minFilter)
        wrapS = try container.decodeIfPresent(Wrap.self, forKey: .wrapS) ?? .REPEAT
        wrapT = try container.decodeIfPresent(Wrap.self, forKey: .wrapT) ?? .REPEAT
        name = try container.decodeIfPresent(String.self, forKey: .name)
    }
}

public struct GLTFScene: Decodable, Resolver {
    public static let documentKeyPath = \GLTFDocument.scenes

    public let nodes: [Index<GLTFNode>]
    public let name: String?
    // let extensions: [String: Any]
    // let extras: Any

    public enum CodingKeys: CodingKey {
        case nodes
        case name
        case extensions
        case extras
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        nodes = try container.decodeIfPresent([Index<GLTFNode>].self, forKey: .nodes) ?? []
        name = try container.decodeIfPresent(String.self, forKey: .name)
    }
}

public struct Skin: Decodable {
    public static let documentKeyPath = \GLTFDocument.skins
}

public struct Texture: Decodable, Resolver {
    public static let documentKeyPath = \GLTFDocument.textures

    public let sampler: Index<Sampler>?
    public let source: Index<Image>?
    public let name: String?
    // let extensions: [String: Any]
    // let extras: Any
}

public struct TextureInfo: Decodable {
    public let index: Index<Texture>
    public let texCoord: Int
    // let extensions: [String: Any]
    // let extras: Any

    public enum CodingKeys: CodingKey {
        case index
        case texCoord
        case extensions
        case extras
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        index = try container.decode(Index<Texture>.self, forKey: .index)
        texCoord = try container.decodeIfPresent(Int.self, forKey: .texCoord) ?? 0
    }
}

// enum CodingKeys: CodingKey {
//    case XXXX
// }
//
// init(from decoder: Decoder) throws {
//    let container = try decoder.container(keyedBy: CodingKeys.self)
//    XXXX = try container.decodeIfPresent(XXXX.self, forKey: XXXX)
// }

public struct MatrixDecoder: Decodable {
    // A floating-point 4x4 transformation matrix stored in column-major order.
    public let matrix: simd_float4x4?

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let floats = try container.decode([Float].self)
        if floats.isEmpty {
            matrix = nil
        }
        else if floats.count == 16 {
            let columns = [
                floats[0 ..< 4],
                floats[4 ..< 8],
                floats[8 ..< 12],
                floats[12 ..< 16],
            ].map { SIMD4<Float>($0) }
            matrix = simd_float4x4(columns)
        }
        else {
            fatalError()
        }
    }
}

public struct URI: Decodable, Hashable {
    public let string: String

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        string = try container.decode(String.self)
    }
}

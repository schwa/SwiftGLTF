// swiftlint:disable file_length
// swiftlint:disable type_name
// swiftlint:disable fatal_error_message

import Foundation
import simd

// https://github.com/KhronosGroup/glTF/tree/master/specification/2.0

public enum GLTFError: Error {
    case unknown
}

public struct Container {
    public enum Kind {
        case json
        case binary(GLB)
    }

    public let url: URL
    public let kind: Kind
    public let document: Document

    public init(url: URL) throws {
        self.url = url
        switch url.pathExtension {
        case "glb":
            let glb = try GLB(url: url)
            kind = .binary(glb)
            document = try glb.document()
        case "gltf":
            kind = .json
            let data = try Data(contentsOf: url)
            document = try JSONDecoder().decode(Document.self, from: data)
        default:
            throw GLTFError.unknown
        }
    }

    public func resolve(path: String) throws -> Data {
        let url = url.deletingLastPathComponent().appendingPathComponent(path)
        return try Data(contentsOf: url)
    }

    public func resolve(chunkIndex: Int) throws -> Data {
        switch kind {
        case .binary(let glb):
            return glb.chunks[chunkIndex].content
        default:
            throw GLTFError.unknown
        }
    }

    class Cache {
        var cache: [URI: Data] = [:]
    }

    let cache = Cache()

    public func data(for uri: URI) throws -> Data {
        if let data = cache.cache[uri] {
            return data
        }
        guard let url = URL(string: uri.string) else {
            throw GLTFError.unknown
        }
        switch url.scheme {
        case "data":
            // https://developer.mozilla.org/en-US/docs/Web/HTTP/Basics_of_HTTP/Data_URLs
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            let parts = components.path.split(separator: ",")
            switch parts[0] {
            case "application/octet-stream;base64", "image/jpeg;base64", "image/png;base64":
                let data = Data(base64Encoded: String(parts[1]))!
                cache.cache[uri] = data
                return data
            default:
                throw GLTFError.unknown
            }
        case .none:
            let url = self.url.deletingLastPathComponent().appendingPathComponent(uri.string)
            return try Data(contentsOf: url)
        default:
            return try Data(contentsOf: url)
        }
    }

    public func data(for bufferView: BufferView) throws -> Data {
        let data = try data(for: bufferView.buffer)
        return data.subdata(in: bufferView.byteOffset ..< (bufferView.byteOffset + bufferView.byteLength))
    }

    public func data(for bufferIndex: Index<Buffer>) throws -> Data {
        let buffer = try bufferIndex.resolve(in: document)
        return try data(for: buffer)
    }
    
    public func data(for buffer: Buffer) throws -> Data {
        switch (buffer.uri, kind) {
        case (nil, .binary(let glb)):
            let chunk = glb.chunks.first(where: { $0.chunkType == .bin })
            return chunk!.content
        default:
            guard let uri = buffer.uri else {
                throw GLTFError.unknown
            }
            return try data(for: uri)
        }
    }

    public func data(for accessor: Accessor) throws -> Data {
        let elementSize: Int
        switch (accessor.componentType, accessor.type) {
        case (.FLOAT, .VEC4):
            elementSize = 16 // TODO:
        case (.FLOAT, .VEC3):
            elementSize = 12 // TODO:
        case (.FLOAT, .VEC2):
            elementSize = 8 // TODO:
        case (.UNSIGNED_INT, .SCALAR):
            elementSize = 4
        case (.UNSIGNED_SHORT, .VEC3):
            elementSize = 6 // TODO:
        case (.UNSIGNED_SHORT, .SCALAR):
            elementSize = 2
        case (.UNSIGNED_BYTE, .SCALAR):
            elementSize = 1
        default:
            throw GLTFError.unknown
        }

        let elementsSize = accessor.count * elementSize

        let subdata: Data
        if let bufferView = try accessor.bufferView?.resolve(in: document) {
            let start = accessor.byteOffset + bufferView.byteOffset
            let data = try data(for: bufferView.buffer)
            subdata = data.subdata(in: start ..< (start + elementsSize))
        }
        else {
            subdata = Data(count: elementsSize)
        }

        assert(subdata.count == elementsSize)
        return subdata
    }
}

// MARK: -

public struct Document: Decodable, Hashable, Sendable {
    public let extensionsUsed: [String]
    public let extensionsRequired: [String]
    public let accessors: [Accessor]
    public let animations: [Animation]
    public let asset: Asset
    public let buffers: [Buffer]
    public let bufferViews: [BufferView]
    public let cameras: [Camera]
    public let images: [Image]
    public let materials: [Material]
    public let meshes: [Mesh]
    public let nodes: [Node]
    public let samplers: [Sampler]
    public let scene: Index<Scene>?
    public let scenes: [Scene]
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
        accessors = try container.decodeIfPresent([Accessor].self, forKey: .accessors) ?? []
        animations = try container.decodeIfPresent([Animation].self, forKey: .animations) ?? []
        asset = try container.decode(Asset.self, forKey: .asset)
        buffers = try container.decodeIfPresent([Buffer].self, forKey: .buffers) ?? []
        bufferViews = try container.decodeIfPresent([BufferView].self, forKey: .bufferViews) ?? []
        cameras = try container.decodeIfPresent([Camera].self, forKey: .cameras) ?? []
        images = try container.decodeIfPresent([Image].self, forKey: .images) ?? []
        materials = try container.decodeIfPresent([Material].self, forKey: .materials) ?? []
        meshes = try container.decodeIfPresent([Mesh].self, forKey: .meshes) ?? []
        nodes = try container.decodeIfPresent([Node].self, forKey: .nodes) ?? []
        samplers = try container.decodeIfPresent([Sampler].self, forKey: .samplers) ?? []
        scene = try container.decodeIfPresent(Index<Scene>.self, forKey: .scene)
        scenes = try container.decodeIfPresent([Scene].self, forKey: .scenes) ?? []
        skins = try container.decodeIfPresent([Skin].self, forKey: .skins) ?? []
        textures = try container.decodeIfPresent([Texture].self, forKey: .textures) ?? []
//        extensions = try container.decodeIfPresent([String].self, forKey: .extensions) ?? []
//        extras = try container.decodeIfPresent([String].self, forKey: .extras) ?? []
    }
}

public struct Accessor: Decodable, Hashable, Sendable, Resolver {
    public static let documentKeyPath = \Document.accessors

    public let bufferView: Index<BufferView>?
    public let byteOffset: Int
    public enum ComponentType: Int, Decodable, Hashable, Sendable {
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
    public enum AttributeType: String, Decodable, Hashable, Sendable {
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

public struct Animation: Decodable, Hashable, Sendable {
    public static let documentKeyPath = \Document.animations
}

public struct Asset: Decodable, Hashable, Sendable {
    public let copyright: String?
    public let generator: String?
    public let version: Version
    public let minVersion: Version?
    // let extensions: [String: Any]?
    // let extras: Any?

    public struct Version: RawRepresentable, Decodable, Hashable, Sendable {
        public init?(rawValue: String) {
            self.rawValue = rawValue
        }

        public let rawValue: String

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            rawValue = try container.decode(String.self)
        }
    }
}

public struct Buffer: Decodable, Hashable, Sendable, Resolver {
    public static let documentKeyPath = \Document.buffers

    public let uri: URI?
    public let byteLength: Int
    public let name: String?
    // let extensions: [String: Any]?
    // let extras: Any?
}

public struct BufferView: Decodable, Hashable, Sendable, Resolver {
    public static let documentKeyPath = \Document.bufferViews

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

public struct Camera: Decodable, Hashable, Sendable, Resolver {
    public static let documentKeyPath = \Document.cameras
}

// TODO:
// public struct Extension: Decodable {
// }

// TODO:
// public struct Extras: Decodable {
// }

public struct Image: Decodable, Hashable, Sendable, Resolver {
    public static let documentKeyPath = \Document.images

    public let uri: URI?
    public let mimetype: String?
    public let bufferView: Index<BufferView>?
    public let name: String?
    // let extensions: [String: Any]?
    // let extras: Any?
}

public struct Material: Decodable, Hashable, Sendable, Resolver {
    public static let documentKeyPath = \Document.materials

    public let name: String?
    // let extensions: [String: Any]?
    // let extras: Any?

    public struct PBRMetallicRoughness: Decodable, Hashable, Sendable {
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

public struct Mesh: Decodable, Hashable, Sendable, Resolver {
    public static let documentKeyPath = \Document.meshes

    public struct Primitive: Decodable, Hashable, Sendable {
        public enum Semantic: String, Decodable, Hashable, Sendable {
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

        public let attributes: [Semantic: Index<Accessor>]
        public let indices: Index<Accessor>?
        public let material: Index<Material>?
        public enum Mode: Int, Decodable, Hashable, Sendable {
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
            attributes = Dictionary(uniqueKeysWithValues: try container.decode([String: Index<Accessor>].self, forKey: .attributes).map { (Semantic(rawValue: $0)!, $1) })
            indices = try container.decodeIfPresent(Index<Accessor>.self, forKey: .indices)
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

public struct Node: Decodable, Hashable, Sendable, Resolver {
    public static let documentKeyPath = \Document.nodes

    public let camera: Index<Camera>?
    public let children: [Index<Node>]
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
        children = try container.decodeIfPresent([Index<Node>].self, forKey: .children) ?? []
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
    
    public func hash(into hasher: inout Hasher) {
        camera?.hash(into: &hasher)
        children.hash(into: &hasher)
        //    let skin: Int?
        matrix?.scalars.hash(into: &hasher)
        mesh.hash(into: &hasher)
        rotation.hash(into: &hasher)
        scale.hash(into: &hasher)
        translation.hash(into: &hasher)
        //    let weights: [Int]?
        name.hash(into: &hasher)
        // let extensions: [String: Any]?
        // let extras: Any?
    }
}

public struct Sampler: Decodable, Hashable, Sendable, Resolver {
    public static let documentKeyPath = \Document.samplers

    public enum MagFilter: Int, Decodable, Hashable, Sendable {
        case NEAREST = 9728
        case LINEAR = 9729
    }

    public enum MinFilter: Int, Decodable, Hashable, Sendable {
        case NEAREST = 9728
        case LINEAR = 9729
        case NEAREST_MIPMAP_NEAREST = 9984
        case LINEAR_MIPMAP_NEAREST = 9985
        case NEAREST_MIPMAP_LINEAR = 9986
        case LINEAR_MIPMAP_LINEAR = 9987
    }

    public enum Wrap: Int, Decodable, Hashable, Sendable {
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

public struct Scene: Decodable, Hashable, Sendable, Resolver {
    public static let documentKeyPath = \Document.scenes

    public let nodes: [Index<Node>]
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
        nodes = try container.decodeIfPresent([Index<Node>].self, forKey: .nodes) ?? []
        name = try container.decodeIfPresent(String.self, forKey: .name)
    }
}

public struct Skin: Decodable, Hashable, Sendable {
    public static let documentKeyPath = \Document.skins
}

public struct Texture: Decodable, Hashable, Sendable, Resolver {
    public static let documentKeyPath = \Document.textures

    public let sampler: Index<Sampler>?
    public let source: Index<Image>?
    public let name: String?
    // let extensions: [String: Any]
    // let extras: Any
}

public struct TextureInfo: Decodable, Hashable, Sendable {
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
                floats[12 ..< 16]
            ].map { SIMD4<Float>($0) }
            matrix = simd_float4x4(columns)
        }
        else {
            throw GLTFError.unknown
        }
    }
}

// MARK: -

public struct URI: Decodable, Hashable, Sendable {
    public let string: String

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        string = try container.decode(String.self)
    }
}

public protocol Resolver: Sendable {
    associatedtype C: RandomAccessCollection where C.Index == Int
    static var documentKeyPath: KeyPath<Document, C> { get }
}

public struct Index<R>: Decodable, Hashable, Sendable where R: Resolver {
    public typealias C = R.C
    public let index: C.Index

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        index = try container.decode(Int.self)
    }

    public func resolve(in document: Document) throws -> C.Element {
        let value = document[keyPath: R.documentKeyPath]
        return value[index]
    }
}

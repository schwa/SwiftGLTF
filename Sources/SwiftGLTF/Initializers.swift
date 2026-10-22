import Foundation
import simd

// Public initializers so consumers can build models in code. Defaults match what decoding fills in for missing keys.

public extension Index {
    init(_ index: Int) {
        self.index = index
    }
}

public extension URI {
    init(_ string: String) {
        self.string = string
    }
}

public extension Asset.Version {
    static let v2_0 = Self(rawValue: "2.0")!
}

public extension Document {
    init(
        asset: Asset = Asset(),
        scene: Index<Scene>? = nil,
        scenes: [Scene] = [],
        nodes: [Node] = [],
        meshes: [Mesh] = [],
        accessors: [Accessor] = [],
        bufferViews: [BufferView] = [],
        buffers: [Buffer] = [],
        materials: [Material] = [],
        textures: [Texture] = [],
        images: [Image] = [],
        samplers: [Sampler] = [],
        cameras: [Camera] = [],
        skins: [Skin] = [],
        animations: [Animation] = [],
        extensionsUsed: [String] = [],
        extensionsRequired: [String] = [],
        extensions: Extensions? = nil,
        extras: JSONValue? = nil
    ) {
        self.extensionsUsed = extensionsUsed
        self.extensionsRequired = extensionsRequired
        self.accessors = accessors
        self.animations = animations
        self.asset = asset
        self.buffers = buffers
        self.bufferViews = bufferViews
        self.cameras = cameras
        self.images = images
        self.materials = materials
        self.meshes = meshes
        self.nodes = nodes
        self.samplers = samplers
        self.scene = scene
        self.scenes = scenes
        self.skins = skins
        self.textures = textures
        self.extensions = extensions
        self.extras = extras
    }
}

public extension Asset {
    init(version: Version = .v2_0, minVersion: Version? = nil, generator: String? = nil, copyright: String? = nil, extensions: Extensions? = nil, extras: JSONValue? = nil) {
        self.version = version
        self.minVersion = minVersion
        self.generator = generator
        self.copyright = copyright
        self.extensions = extensions
        self.extras = extras
    }
}

public extension Accessor {
    init(
        bufferView: Index<BufferView>?,
        byteOffset: Int = 0,
        componentType: ComponentType,
        normalized: Bool = false,
        count: Int,
        type: AttributeType,
        max: [Double]? = nil,
        min: [Double]? = nil,
        sparse: Sparse? = nil,
        name: String? = nil,
        extensions: Extensions? = nil,
        extras: JSONValue? = nil
    ) {
        self.bufferView = bufferView
        self.byteOffset = byteOffset
        self.componentType = componentType
        self.normalized = normalized
        self.count = count
        self.type = type
        self.max = max
        self.min = min
        self.sparse = sparse
        self.name = name
        self.extensions = extensions
        self.extras = extras
    }
}

public extension Accessor.Sparse.Indices {
    init(bufferView: Index<BufferView>, byteOffset: Int = 0, componentType: Accessor.ComponentType, extensions: Extensions? = nil, extras: JSONValue? = nil) {
        self.bufferView = bufferView
        self.byteOffset = byteOffset
        self.componentType = componentType
        self.extensions = extensions
        self.extras = extras
    }
}

public extension Accessor.Sparse.Values {
    init(bufferView: Index<BufferView>, byteOffset: Int = 0, extensions: Extensions? = nil, extras: JSONValue? = nil) {
        self.bufferView = bufferView
        self.byteOffset = byteOffset
        self.extensions = extensions
        self.extras = extras
    }
}

public extension Buffer {
    init(byteLength: Int, uri: URI? = nil, name: String? = nil, extensions: Extensions? = nil, extras: JSONValue? = nil) {
        self.byteLength = byteLength
        self.uri = uri
        self.name = name
        self.extensions = extensions
        self.extras = extras
    }
}

public extension BufferView {
    init(
        buffer: Index<Buffer>,
        byteOffset: Int = 0,
        byteLength: Int,
        byteStride: Int? = nil,
        target: Target? = nil,
        name: String? = nil,
        extensions: Extensions? = nil,
        extras: JSONValue? = nil
    ) {
        self.buffer = buffer
        self.byteOffset = byteOffset
        self.byteLength = byteLength
        self.byteStride = byteStride
        self.target = target
        self.name = name
        self.extensions = extensions
        self.extras = extras
    }
}

public extension Material.PBRMetallicRoughness {
    init(
        baseColorFactor: SIMD4<Float> = [1, 1, 1, 1],
        baseColorTexture: TextureInfo? = nil,
        metallicFactor: Float = 1,
        roughnessFactor: Float = 1,
        metallicRoughnessTexture: TextureInfo? = nil,
        extensions: Extensions? = nil,
        extras: JSONValue? = nil
    ) {
        self.baseColorFactor = baseColorFactor
        self.baseColorTexture = baseColorTexture
        self.metallicFactor = metallicFactor
        self.roughnessFactor = roughnessFactor
        self.metallicRoughnessTexture = metallicRoughnessTexture
        self.extensions = extensions
        self.extras = extras
    }
}

public extension Mesh {
    init(primitives: [Primitive], weights: [Float] = [], name: String? = nil, extensions: Extensions? = nil, extras: JSONValue? = nil) {
        self.primitives = primitives
        self.weights = weights
        self.name = name
        self.extensions = extensions
        self.extras = extras
    }
}

public extension Mesh.Primitive {
    init(
        attributes: [Semantic: Index<Accessor>],
        indices: Index<Accessor>? = nil,
        material: Index<Material>? = nil,
        mode: Mode = .TRIANGLES,
        targets: [[Semantic: Index<Accessor>]] = [],
        extensions: Extensions? = nil,
        extras: JSONValue? = nil
    ) {
        self.attributes = attributes
        self.indices = indices
        self.material = material
        self.mode = mode
        self.targets = targets
        self.extensions = extensions
        self.extras = extras
    }
}

public extension Node {
    init(
        name: String? = nil,
        children: [Index<Node>] = [],
        mesh: Index<Mesh>? = nil,
        camera: Index<Camera>? = nil,
        skin: Index<Skin>? = nil,
        matrix: simd_float4x4? = nil,
        translation: SIMD3<Float>? = nil,
        rotation: SIMD4<Float>? = nil,
        scale: SIMD3<Float>? = nil,
        weights: [Float]? = nil,
        extensions: Extensions? = nil,
        extras: JSONValue? = nil
    ) {
        self.name = name
        self.children = children
        self.mesh = mesh
        self.camera = camera
        self.skin = skin
        self.matrix = matrix
        self.translation = translation
        self.rotation = rotation
        self.scale = scale
        self.weights = weights
        self.extensions = extensions
        self.extras = extras
    }
}

public extension Sampler {
    init(magFilter: MagFilter? = nil, minFilter: MinFilter? = nil, wrapS: Wrap = .REPEAT, wrapT: Wrap = .REPEAT, name: String? = nil, extensions: Extensions? = nil, extras: JSONValue? = nil) {
        self.magFilter = magFilter
        self.minFilter = minFilter
        self.wrapS = wrapS
        self.wrapT = wrapT
        self.name = name
        self.extensions = extensions
        self.extras = extras
    }
}

public extension Scene {
    init(nodes: [Index<Node>] = [], name: String? = nil, extensions: Extensions? = nil, extras: JSONValue? = nil) {
        self.nodes = nodes
        self.name = name
        self.extensions = extensions
        self.extras = extras
    }
}

public extension Texture {
    init(source: Index<Image>? = nil, sampler: Index<Sampler>? = nil, name: String? = nil, extensions: Extensions? = nil, extras: JSONValue? = nil) {
        self.source = source
        self.sampler = sampler
        self.name = name
        self.extensions = extensions
        self.extras = extras
    }
}

public extension TextureInfo {
    init(index: Index<Texture>, texCoord: Int = 0, scale: Float? = nil, strength: Float? = nil, extensions: Extensions? = nil, extras: JSONValue? = nil) {
        self.index = index
        self.texCoord = texCoord
        self.scale = scale
        self.strength = strength
        self.extensions = extensions
        self.extras = extras
    }
}

public extension Skin {
    init(joints: [Index<Node>], inverseBindMatrices: Index<Accessor>? = nil, skeleton: Index<Node>? = nil, name: String? = nil, extensions: Extensions? = nil, extras: JSONValue? = nil) {
        self.joints = joints
        self.inverseBindMatrices = inverseBindMatrices
        self.skeleton = skeleton
        self.name = name
        self.extensions = extensions
        self.extras = extras
    }
}

public extension Animation.Sampler {
    init(input: Index<Accessor>, output: Index<Accessor>, interpolation: Animation.Interpolation = .LINEAR, extensions: Extensions? = nil, extras: JSONValue? = nil) {
        self.input = input
        self.output = output
        self.interpolation = interpolation
        self.extensions = extensions
        self.extras = extras
    }
}

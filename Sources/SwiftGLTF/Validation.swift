import Foundation

public struct ValidationIssue: Hashable, Sendable, CustomStringConvertible {
    public enum Severity: Sendable {
        case error
        case warning
    }

    public let severity: Severity
    public let path: String // JSON-pointer style, e.g. /accessors/3/bufferView
    public let message: String

    public var description: String {
        "\(severity == .error ? "error" : "warning"): \(path): \(message)"
    }
}

public extension Document {
    /// Extensions SwiftGLTF reads into typed values, or handles while reading accessors (quantized attributes).
    /// Used to flag unsupported required ones. Clients that implement more (other materials, compression through
    /// ``BufferViewDecoder``) add their names; ``Container/supportedExtensions`` adds the registered decoders'.
    static let supportedExtensions: Set<String> = [
        KHRLightsPunctual.extensionName,
        KHRTextureTransform.extensionName,
        KHRMaterialsUnlit.extensionName,
        KHRMaterialsEmissiveStrength.extensionName,
        KHRMaterialsIOR.extensionName,
        KHRMaterialsSpecular.extensionName,
        KHRMaterialsTransmission.extensionName,
        KHRMaterialsVolume.extensionName,
        EXTTextureWebP.extensionName,
        // Normalized and integer attribute types, handled by the accessor reader.
        "KHR_mesh_quantization",
    ]

    // Structural validation: index bounds, accessor/bufferView ranges, attribute
    // rules, extensions, and node graph. Collects every issue rather than
    // stopping at the first.
    func validate() -> [ValidationIssue] {
        var validator = Validator(document: self)
        validator.run()
        return validator.issues
    }
}

private struct Validator {
    let document: Document
    var issues: [ValidationIssue] = []

    mutating func error(_ path: String, _ message: String) {
        issues.append(ValidationIssue(severity: .error, path: path, message: message))
    }

    mutating func warning(_ path: String, _ message: String) {
        issues.append(ValidationIssue(severity: .warning, path: path, message: message))
    }

    mutating func check<R>(_ index: Index<R>?, _ path: String) {
        guard let index else {
            return
        }
        if !index.isValid(in: document) {
            error(path, "index \(index.index) is out of range for \(R.self)")
        }
    }

    mutating func run() {
        checkExtensions()
        checkBufferViews()
        checkAccessors()
        checkMeshes()
        checkTexturesAndMaterials()
        checkNodesAndScenes()
        checkSkinsAndAnimations()
    }

    mutating func checkSkinsAndAnimations() {
        for (index, skin) in document.skins.enumerated() {
            let path = "/skins/\(index)"
            check(skin.inverseBindMatrices, "\(path)/inverseBindMatrices")
            check(skin.skeleton, "\(path)/skeleton")
            for (offset, joint) in skin.joints.enumerated() {
                check(joint, "\(path)/joints/\(offset)")
            }
            if let matrices = skin.inverseBindMatrices, matrices.isValid(in: document),
               document.accessors[matrices.index].count < skin.joints.count {
                error("\(path)/inverseBindMatrices", "fewer matrices than joints")
            }
        }
        for (animationIndex, animation) in document.animations.enumerated() {
            let path = "/animations/\(animationIndex)"
            for (offset, sampler) in animation.samplers.enumerated() {
                check(sampler.input, "\(path)/samplers/\(offset)/input")
                check(sampler.output, "\(path)/samplers/\(offset)/output")
            }
            for (offset, channel) in animation.channels.enumerated() {
                check(channel.target.node, "\(path)/channels/\(offset)/target/node")
                if !animation.samplers.indices.contains(channel.sampler) {
                    error("\(path)/channels/\(offset)/sampler", "sampler \(channel.sampler) is out of range")
                }
            }
        }
    }

    mutating func checkExtensions() {
        for name in document.extensionsRequired where !Document.supportedExtensions.contains(name) {
            error("/extensionsRequired", "required extension '\(name)' is not supported")
        }
        for name in document.extensionsUsed where !Document.supportedExtensions.contains(name) {
            warning("/extensionsUsed", "extension '\(name)' is not supported and will be ignored")
        }
        for name in document.extensionsRequired where !document.extensionsUsed.contains(name) {
            error("/extensionsRequired", "'\(name)' is required but not listed in extensionsUsed")
        }
    }

    mutating func checkBufferViews() {
        for (index, view) in document.bufferViews.enumerated() {
            let path = "/bufferViews/\(index)"
            check(view.buffer, "\(path)/buffer")
            guard view.buffer.isValid(in: document) else {
                continue
            }
            let buffer = document.buffers[view.buffer.index]
            if view.byteOffset + view.byteLength > buffer.byteLength {
                error(path, "range \(view.byteOffset)+\(view.byteLength) exceeds buffer byteLength \(buffer.byteLength)")
            }
            if let stride = view.byteStride, !(4 ... 252).contains(stride) || !stride.isMultiple(of: 4) {
                error("\(path)/byteStride", "byteStride \(stride) must be a multiple of 4 in 4...252")
            }
        }
    }

    mutating func checkAccessors() {
        for (index, accessor) in document.accessors.enumerated() {
            let path = "/accessors/\(index)"
            check(accessor.bufferView, "\(path)/bufferView")
            if accessor.count < 1 {
                error("\(path)/count", "count must be >= 1")
            }
            if let viewIndex = accessor.bufferView, viewIndex.isValid(in: document) {
                let view = document.bufferViews[viewIndex.index]
                let elementSize = accessor.componentType.size * accessor.type.componentCount
                let stride = view.byteStride ?? elementSize
                let required = accessor.byteOffset + stride * (accessor.count - 1) + elementSize
                if required > view.byteLength {
                    error(path, "needs \(required) bytes but bufferView \(viewIndex.index) has \(view.byteLength)")
                }
            }
            if let sparse = accessor.sparse {
                check(sparse.indices.bufferView, "\(path)/sparse/indices/bufferView")
                check(sparse.values.bufferView, "\(path)/sparse/values/bufferView")
                if sparse.count > accessor.count {
                    error("\(path)/sparse/count", "sparse count \(sparse.count) exceeds accessor count \(accessor.count)")
                }
            }
        }
    }

    mutating func checkMeshes() {
        for (meshIndex, mesh) in document.meshes.enumerated() {
            for (primitiveIndex, primitive) in mesh.primitives.enumerated() {
                let path = "/meshes/\(meshIndex)/primitives/\(primitiveIndex)"
                check(primitive.indices, "\(path)/indices")
                check(primitive.material, "\(path)/material")
                if primitive.attributes[.POSITION] == nil {
                    warning("\(path)/attributes", "primitive has no POSITION")
                }
                var counts: Set<Int> = []
                for (semantic, accessorIndex) in primitive.attributes {
                    check(accessorIndex, "\(path)/attributes/\(semantic.rawValue)")
                    if accessorIndex.isValid(in: document) {
                        counts.insert(document.accessors[accessorIndex.index].count)
                    }
                }
                if counts.count > 1 {
                    error("\(path)/attributes", "attribute accessors have differing counts \(counts.sorted())")
                }
                for (targetIndex, target) in primitive.targets.enumerated() {
                    for (semantic, accessorIndex) in target {
                        let targetPath = "\(path)/targets/\(targetIndex)/\(semantic.rawValue)"
                        check(accessorIndex, targetPath)
                        if accessorIndex.isValid(in: document), let base = counts.first,
                           document.accessors[accessorIndex.index].count != base {
                            error(targetPath, "target count differs from base attribute count \(base)")
                        }
                    }
                }
                if !mesh.weights.isEmpty, !primitive.targets.isEmpty, mesh.weights.count != primitive.targets.count {
                    error("/meshes/\(meshIndex)/weights", "\(mesh.weights.count) weights for \(primitive.targets.count) targets")
                }
            }
        }
    }

    mutating func checkTexturesAndMaterials() {
        for (index, texture) in document.textures.enumerated() {
            check(texture.source, "/textures/\(index)/source")
            check(texture.sampler, "/textures/\(index)/sampler")
        }
        for (index, material) in document.materials.enumerated() {
            let path = "/materials/\(index)"
            let infos: [(String, TextureInfo?)] = [
                ("pbrMetallicRoughness/baseColorTexture", material.pbrMetallicRoughness?.baseColorTexture),
                ("pbrMetallicRoughness/metallicRoughnessTexture", material.pbrMetallicRoughness?.metallicRoughnessTexture),
                ("normalTexture", material.normalTexture),
                ("occlusionTexture", material.occlusionTexture),
                ("emissiveTexture", material.emissiveTexture)
            ]
            for (name, info) in infos {
                check(info?.index, "\(path)/\(name)/index")
                // scale belongs to normalTextureInfo, strength to occlusionTextureInfo.
                if info?.scale != nil, name != "normalTexture" {
                    warning("\(path)/\(name)/scale", "scale is only defined for normalTexture")
                }
                if info?.strength != nil, name != "occlusionTexture" {
                    warning("\(path)/\(name)/strength", "strength is only defined for occlusionTexture")
                }
            }
        }
    }

    mutating func checkNodesAndScenes() {
        var parentCount = [Int](repeating: 0, count: document.nodes.count)
        for (index, node) in document.nodes.enumerated() {
            let path = "/nodes/\(index)"
            check(node.mesh, "\(path)/mesh")
            check(node.camera, "\(path)/camera")
            check(node.skin, "\(path)/skin")
            for (childOffset, child) in node.children.enumerated() {
                check(child, "\(path)/children/\(childOffset)")
                if child.isValid(in: document) {
                    parentCount[child.index] += 1
                }
            }
        }
        for (index, count) in parentCount.enumerated() where count > 1 {
            error("/nodes/\(index)", "node has \(count) parents (must be a tree)")
        }
        if hasCycle() {
            error("/nodes", "node hierarchy contains a cycle")
        }
        check(document.scene, "/scene")
        for (sceneIndex, scene) in document.scenes.enumerated() {
            for (offset, node) in scene.nodes.enumerated() {
                check(node, "/scenes/\(sceneIndex)/nodes/\(offset)")
            }
        }
    }

    func hasCycle() -> Bool {
        // 0 = unvisited, 1 = on stack, 2 = done
        var state = [Int](repeating: 0, count: document.nodes.count)
        func visit(_ index: Int) -> Bool {
            if state[index] == 1 {
                return true
            }
            if state[index] == 2 {
                return false
            }
            state[index] = 1
            for child in document.nodes[index].children where child.isValid(in: document) {
                if visit(child.index) {
                    return true
                }
            }
            state[index] = 2
            return false
        }
        return document.nodes.indices.contains { visit($0) }
    }
}

extension Accessor.ComponentType {
    var size: Int {
        switch self {
        case .BYTE, .UNSIGNED_BYTE: return 1
        case .SHORT, .UNSIGNED_SHORT: return 2
        case .UNSIGNED_INT, .FLOAT: return 4
        }
    }
}

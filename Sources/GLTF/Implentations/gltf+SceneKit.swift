import CoreImage
import Everything
import Foundation
import SceneKit
import SIMDSupport

// swiftlint:disable fatal_error_message

public class SceneKitGenerator {
    let rootURL: URL?
    let document: GLTFDocument

    var cachedData: [Index<Buffer>: Data] = [:]

    public init(rootURL: URL? = nil, document: GLTFDocument) {
        self.rootURL = rootURL
        self.document = document
    }

    public func generateSCNScene() throws -> SCNScene {
        let scnScene = SCNScene()
        let scene = try document.scene.map { try $0.resolve(in: document) } ?? document.scenes.first!
        try scene.nodes
            .map { try $0.resolve(in: document) }
            .map { try generateSCNNode(from: $0) }
            .forEach {
                scnScene.rootNode.addChildNode($0)
            }
        return scnScene
    }

    func generateSCNNode(from node: GLTFNode) throws -> SCNNode {
        let geometry = try node.mesh.map { try generateSCNGeometry(from: $0.resolve(in: document)) }
        let scnNode = SCNNode(geometry: geometry)

        if let matrix = node.matrix {
            scnNode.simdTransform = matrix
        }

        if let translation = node.translation {
            scnNode.simdPosition = translation
        }

        if let rotation = node.rotation {
            scnNode.simdRotation = rotation
        }

        if let scale = node.scale {
            scnNode.simdScale = scale
        }

        try node.children.map { try $0.resolve(in: document) }.map { try generateSCNNode(from: $0) }.forEach {
            scnNode.addChildNode($0)
        }
        return scnNode
    }

    func resolve(uri: URI) -> URL {
        let url = URL(string: uri.string)
        if let url = url, url.scheme != nil {
            return url
        }
        else {
            guard let rootURL = rootURL else {
                fatalError()
            }
            let url = rootURL.deletingLastPathComponent().appendingPathComponent(uri.string)
            return url
        }
    }

    private func data(for bufferIndex: Index<Buffer>) throws -> Data {
        if let data = cachedData[bufferIndex] {
            return data
        }
        else {
            let buffer = try bufferIndex.resolve(in: document)
            guard let uri = buffer.uri else {
                fatalError()
            }

            let url = resolve(uri: uri)
            let data = try Data(contentsOf: url)

            cachedData[bufferIndex] = data
            return data
        }
    }

    func generateSCNGeometrySource(semantic: SCNGeometrySource.Semantic, from accessor: GLTFAccessor) throws -> SCNGeometrySource {
        let bufferView = try accessor.bufferView!.resolve(in: document)
        let bufferData = try data(for: bufferView.buffer)
            .subdata(in: bufferView.byteOffset ..< (bufferView.byteOffset + bufferView.byteLength))

        let usesFloatComponents: Bool
        let bytesPerComponent: Int
        switch accessor.componentType {
        case .FLOAT:
            usesFloatComponents = true
            bytesPerComponent = MemoryLayout<Float>.size
        case .BYTE:
            usesFloatComponents = false
            bytesPerComponent = MemoryLayout<UInt8>.size
        default:
            fatalError()
        }

        let componentsPerVector: Int
        switch accessor.type {
        case .VEC2:
            componentsPerVector = 2
        case .VEC3:
            componentsPerVector = 3
        case .VEC4:
            componentsPerVector = 4
        default:
            fatalError()
        }

        let scnSource = SCNGeometrySource(data: bufferData, semantic: semantic, vectorCount: accessor.count, usesFloatComponents: usesFloatComponents, componentsPerVector: componentsPerVector, bytesPerComponent: bytesPerComponent, dataOffset: 0, dataStride: bufferView.byteStride ?? 0)
        return scnSource
    }

    func generateSCNGeometry(from mesh: Mesh) throws -> SCNGeometry {
        let sourcesAndElements: [([SCNGeometrySource], SCNGeometryElement?, [SCNMaterial])] = try mesh.primitives.map { primitive in
            let semantics: [(Mesh.Primitive.Semantic, SCNGeometrySource.Semantic?)] = [
                (.POSITION, .vertex),
                (.NORMAL, .normal),
                (.TANGENT, .tangent),
                (.TEXCOORD_0, .texcoord),
                (.TEXCOORD_1, nil),
                (.COLOR_0, .color),
                (.JOINTS_0, nil),
                (.WEIGHTS_0, nil),
            ]

            let sources: [SCNGeometrySource] = try semantics.compactMap {
                guard let accessor = try primitive.attributes[$0.0]?.resolve(in: document) else {
                    return nil
                }
                guard let scnSemantic = $0.1 else {
                    warning("No semantic for \($0.0)")
                    return nil
                }
                let source = try generateSCNGeometrySource(semantic: scnSemantic, from: accessor)
                return source
            }

            var scnElement: SCNGeometryElement?
            if let indicesAccessor = try primitive.indices?.resolve(in: document) {
                let indicesBufferView = try indicesAccessor.bufferView!.resolve(in: document)
                let indicesData = try data(for: indicesBufferView.buffer)

                let primitiveType: SCNGeometryPrimitiveType
                let primitiveCount: Int

                switch primitive.mode {
                case .TRIANGLES:
                    primitiveType = .triangles
                    primitiveCount = indicesAccessor.count / 3
                default:
                    fatalError()
                }

                let bytesPerIndex: Int
                switch (indicesAccessor.type, indicesAccessor.componentType) {
                case (.SCALAR, .UNSIGNED_BYTE):
                    bytesPerIndex = MemoryLayout<UInt8>.size
                case (.SCALAR, .UNSIGNED_SHORT):
                    bytesPerIndex = MemoryLayout<UInt16>.size
                case (.SCALAR, .UNSIGNED_INT):
                    bytesPerIndex = MemoryLayout<UInt32>.size
                default:
                    fatalError()
                }

                let indicesSubData = indicesData.subdata(in: indicesBufferView.byteOffset ..< (indicesBufferView.byteOffset + indicesBufferView.byteLength))

                scnElement = SCNGeometryElement(data: indicesSubData, primitiveType: primitiveType, primitiveCount: primitiveCount, bytesPerIndex: bytesPerIndex)
            }

            let material = try primitive.material?.resolve(in: document)
            let scnMaterial = try material.map { try generateSCNMaterial(from: $0) }

            return (sources, scnElement, [scnMaterial].compactMap { $0 })
        }

        let sources = sourcesAndElements.flatMap(\.0)
        let elements = sourcesAndElements.compactMap(\.1)
        let materials = sourcesAndElements.flatMap(\.2)

        let geometry = SCNGeometry(sources: sources, elements: elements)
        geometry.materials = materials
        return geometry
    }

    func generateSCNMaterial(from material: Material) throws -> SCNMaterial {
        let scnMaterial = SCNMaterial()

        if let pbrMetallicRoughness = material.pbrMetallicRoughness {
            scnMaterial.lightingModel = .physicallyBased
            if let texture = pbrMetallicRoughness.baseColorTexture {
                try configureSCNMaterialProperty(property: scnMaterial.diffuse, from: texture)
            }
            else {
                scnMaterial.diffuse.contents = pbrMetallicRoughness.baseColorFactor.cgColor
            }

            if let metallicRoughnessTexture = pbrMetallicRoughness.metallicRoughnessTexture {
                warning(pbrMetallicRoughness.metallicFactor == 1)
                warning(pbrMetallicRoughness.roughnessFactor == 1)
                try configureSCNMaterialProperty(property: scnMaterial.metalness, channel: .blue, from: metallicRoughnessTexture)
                try configureSCNMaterialProperty(property: scnMaterial.roughness, channel: .green, from: metallicRoughnessTexture)
            }
            else {
                scnMaterial.metalness.contents = pbrMetallicRoughness.metallicFactor
                scnMaterial.roughness.contents = pbrMetallicRoughness.roughnessFactor
            }
        }

        if let normalTexture = material.normalTexture {
            try configureSCNMaterialProperty(property: scnMaterial.normal, from: normalTexture)
        }

        if let occlusionTexture = material.occlusionTexture {
            warning("Hopefully ambientOcclusion == occlusionTexture")
            try configureSCNMaterialProperty(property: scnMaterial.ambientOcclusion, from: occlusionTexture)
        }

        if let emissiveTexture = material.emissiveTexture {
            try configureSCNMaterialProperty(property: scnMaterial.emission, from: emissiveTexture)
            warning(material.emissiveFactor == nil || material.emissiveFactor == [1, 1, 1])
        }
        else if let emissiveFactor = material.emissiveFactor {
            scnMaterial.emission.contents = SIMD4<Float>(emissiveFactor.x, emissiveFactor.y, emissiveFactor.z, 1).cgColor
        }

        warning(material.alphaMode == nil, "alphaMode == nil")
        warning(material.alphaCutoff == nil)
        warning(material.doubleSided == nil)

//        scnMaterial.roughness.contents = roughnessTextureImage
//        scnMaterial.metalness.contents = material.pbrMetallicRoughness.metallicFactor!
//        scnMaterial.normal.contents = NSColor.red

        return scnMaterial
    }

    enum Channel {
        case red
        case green
        case blue
    }

    func configureSCNMaterialProperty(property: SCNMaterialProperty, channel: Channel? = nil, from textureInfo: TextureInfo) throws {
        warning(textureInfo.texCoord == 0)
        let texture = try textureInfo.index.resolve(in: document)
        let sampler = try texture.sampler?.resolve(in: document) ?? Sampler()
        let source = try texture.source!.resolve(in: document)
        let url = resolve(uri: source.uri!)
        let cgImage: CGImage = try {
            let cgImage = try CGImage.load(contentsOf: url)
            switch channel {
            case .none:
                return cgImage
            case .red:
                return cgImage.redChannel
            case .green:
                return cgImage.greenChannel
            case .blue:
                return cgImage.blueChannel
            }
        }()

        property.contents = cgImage
        property.wrapS = SCNWrapMode(sampler.wrapS)
        property.wrapT = SCNWrapMode(sampler.wrapT)
        if let magfilter = sampler.magFilter.map(SCNFilterMode.init) {
            property.magnificationFilter = magfilter
        }
        if let minfilter = sampler.minFilter.map(SCNFilterMode.init) {
            property.minificationFilter = minfilter
        }
    }
}

extension CGImage {
    static func load(contentsOf url: URL) throws -> CGImage {
        #if os(macOS)
            return NSImage(contentsOf: url)!.cgImage
        #else
            fatalError()
        #endif
    }
}

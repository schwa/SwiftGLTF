// swiftlint:disable file_length type_body_length

import CoreImage
// import Everything
import Foundation
import ImageIO
import os
import SceneKit
// import SIMDSupport

public class SceneKitGenerator {
    let rootURL: URL?
    let document: Document
    let binaryBuffer: Data?

    var cachedData: [Index<Buffer>: Data] = [:]

    public init(rootURL: URL? = nil, document: Document, binaryBuffer: Data? = nil) {
        self.rootURL = rootURL
        self.document = document
        self.binaryBuffer = binaryBuffer
    }

    public convenience init(container: Container) {
        var binary: Data?
        if case let .binary(glb) = container.kind {
            binary = glb.chunks.first(where: { $0.chunkType == .bin })?.content
        }
        self.init(rootURL: container.url, document: container.document, binaryBuffer: binary)
    }

    public func generateSCNScene() throws -> SCNScene {
        let scnScene = SCNScene()
        // 'scenes' is optional in glTF; with none there is nothing to show.
        guard let scene = try document.scene.map({ try $0.resolve(in: document) }) ?? document.scenes.first else {
            return scnScene
        }
        try scene.nodes
            .map { try $0.resolve(in: document) }
            .map { try generateSCNNode(from: $0) }
            .forEach {
                scnScene.rootNode.addChildNode($0)
            }
        return scnScene
    }

    func generateSCNNode(from node: Node) throws -> SCNNode {
        let geometry = try node.mesh.map { try generateSCNGeometry(from: $0.resolve(in: document)) }
        let scnNode = SCNNode(geometry: geometry)

        if let cameraIndex = node.camera {
            scnNode.camera = makeSCNCamera(from: try cameraIndex.resolve(in: document))
        }

        if let light = node.punctualLight(in: document) {
            scnNode.light = makeSCNLight(from: light)
        }

        if let matrix = node.matrix {
            scnNode.simdTransform = matrix
        }

        if let translation = node.translation {
            scnNode.simdPosition = translation
        }

        if let rotation = node.rotation {
            // glTF rotation is a quaternion [x, y, z, w], not axis-angle.
            scnNode.simdOrientation = simd_quatf(vector: rotation)
        }

        if let scale = node.scale {
            scnNode.simdScale = scale
        }

        try node.children.map { try $0.resolve(in: document) }.map { try generateSCNNode(from: $0) }.forEach {
            scnNode.addChildNode($0)
        }
        return scnNode
    }

    func makeSCNLight(from light: Light) -> SCNLight {
        let scnLight = SCNLight()
        switch light.type {
        case .directional:
            scnLight.type = .directional
        case .point:
            scnLight.type = .omni
        case .spot:
            scnLight.type = .spot
            if let spot = light.spot {
                scnLight.spotInnerAngle = Double(spot.innerConeAngle) * 180 / .pi
                scnLight.spotOuterAngle = Double(spot.outerConeAngle) * 180 / .pi
            }
        }
        scnLight.color = CGColor(
            red: Double(light.color.x),
            green: Double(light.color.y),
            blue: Double(light.color.z),
            alpha: 1
        )
        scnLight.intensity = CGFloat(light.intensity)
        return scnLight
    }

    func makeSCNCamera(from camera: Camera) -> SCNCamera {
        let scnCamera = SCNCamera()
        switch camera.type {
        case .perspective:
            if let perspective = camera.perspective {
                scnCamera.projectionDirection = .vertical
                scnCamera.fieldOfView = CGFloat(perspective.yfov) * 180 / .pi
                scnCamera.zNear = Double(perspective.znear)
                if let zfar = perspective.zfar {
                    scnCamera.zFar = Double(zfar)
                }
            }
        case .orthographic:
            if let orthographic = camera.orthographic {
                scnCamera.usesOrthographicProjection = true
                scnCamera.orthographicScale = Double(orthographic.ymag)
                scnCamera.zNear = Double(orthographic.znear)
                scnCamera.zFar = Double(orthographic.zfar)
            }
        }
        return scnCamera
    }

    func resolve(uri: URI) throws -> URL {
        let url = URL(string: uri.string)
        if let url = url, url.scheme != nil {
            return url
        }
        else {
            guard let rootURL = rootURL else {
                throw GLTFError.missingResource("Relative URI '\(uri.string)' needs a rootURL")
            }
            return rootURL.deletingLastPathComponent().appendingPathComponent(uri.relativePath)
        }
    }

    // Loads an image's bytes whether it is referenced by uri (file/data URL) or
    // stored in a buffer view (e.g. inside a GLB binary chunk).
    private func imageData(for image: Image) throws -> Data {
        if let uri = image.uri {
            return try Data(contentsOf: resolve(uri: uri))
        }
        if let bufferViewIndex = image.bufferView {
            let bufferView = try bufferViewIndex.resolve(in: document)
            let bufferData = try data(for: bufferView.buffer)
            return bufferData.subdata(in: bufferView.byteOffset ..< (bufferView.byteOffset + bufferView.byteLength))
        }
        throw GLTFError.missingResource("Image has neither uri nor bufferView")
    }

    private func data(for bufferIndex: Index<Buffer>) throws -> Data {
        if let data = cachedData[bufferIndex] {
            return data
        }
        else {
            let buffer = try bufferIndex.resolve(in: document)
            guard let uri = buffer.uri else {
                // A GLB's binary buffer has no uri; it lives in the BIN chunk.
                guard let binaryBuffer else {
                    throw GLTFError.missingResource("Buffer has no uri and no GLB binary buffer is available")
                }
                cachedData[bufferIndex] = binaryBuffer
                return binaryBuffer
            }

            let url = try resolve(uri: uri)
            let data = try Data(contentsOf: url)

            cachedData[bufferIndex] = data
            return data
        }
    }

    func generateSCNGeometrySource(semantic: SCNGeometrySource.Semantic, from accessor: Accessor) throws -> SCNGeometrySource {
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
            throw GLTFError.unsupported("Unsupported accessor component type \(accessor.componentType)")
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
            throw GLTFError.unsupported("Unsupported accessor type \(accessor.type)")
        }

        let elementSize = componentsPerVector * bytesPerComponent
        let bufferData: Data
        let dataOffset: Int
        let dataStride: Int
        if let bufferView = try accessor.bufferView?.resolve(in: document) {
            // `bufferData` starts at the buffer view; the accessor's byteOffset is
            // relative to that, and matters for interleaved buffer views.
            bufferData = try data(for: bufferView.buffer)
                .subdata(in: bufferView.byteOffset ..< (bufferView.byteOffset + bufferView.byteLength))
            dataOffset = accessor.byteOffset
            dataStride = bufferView.byteStride ?? elementSize
        }
        else {
            // No bufferView: the accessor is all zeros.
            bufferData = Data(count: accessor.count * elementSize)
            dataOffset = 0
            dataStride = elementSize
        }
        return SCNGeometrySource(
            data: bufferData,
            semantic: semantic,
            vectorCount: accessor.count,
            usesFloatComponents: usesFloatComponents,
            componentsPerVector: componentsPerVector,
            bytesPerComponent: bytesPerComponent,
            dataOffset: dataOffset,
            dataStride: dataStride
        )
    }

    struct PrimitiveGeometry {
        var sources: [SCNGeometrySource]
        var element: SCNGeometryElement?
        var materials: [SCNMaterial]
    }

    func generateSCNGeometry(from mesh: Mesh) throws -> SCNGeometry {
        let sourcesAndElements: [PrimitiveGeometry] = try mesh.primitives.map { primitive in
            let semantics: [(Mesh.Primitive.Semantic, SCNGeometrySource.Semantic?)] = [
                (.POSITION, .vertex),
                (.NORMAL, .normal),
                (.TANGENT, .tangent),
                (.TEXCOORD_0, .texcoord),
                (.TEXCOORD_1, .texcoord),
                (.COLOR_0, .color),
                (.JOINTS_0, nil),
                (.WEIGHTS_0, nil)
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
                let primitiveType: SCNGeometryPrimitiveType
                let primitiveCount: Int

                switch primitive.mode {
                case .TRIANGLES:
                    primitiveType = .triangles
                    primitiveCount = indicesAccessor.count / 3
                default:
                    throw GLTFError.unsupported("Unsupported primitive mode \(primitive.mode)")
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
                    throw GLTFError.unsupported("Unsupported index type \(indicesAccessor.type)/\(indicesAccessor.componentType)")
                }

                let indicesLength = indicesAccessor.count * bytesPerIndex
                let indicesSubData: Data
                if let indicesBufferView = try indicesAccessor.bufferView?.resolve(in: document) {
                    let indicesStart = indicesBufferView.byteOffset + indicesAccessor.byteOffset
                    indicesSubData = try data(for: indicesBufferView.buffer).subdata(in: indicesStart ..< (indicesStart + indicesLength))
                }
                else {
                    indicesSubData = Data(count: indicesLength) // no bufferView: all zeros
                }

                scnElement = SCNGeometryElement(data: indicesSubData, primitiveType: primitiveType, primitiveCount: primitiveCount, bytesPerIndex: bytesPerIndex)
            }
            else if let positions = try primitive.attributes[.POSITION]?.resolve(in: document) {
                // Non-indexed: vertices are drawn in order.
                guard primitive.mode == .TRIANGLES else {
                    throw GLTFError.unsupported("Unsupported primitive mode \(primitive.mode)")
                }
                let indices = Array(0 ..< UInt32(positions.count))
                scnElement = SCNGeometryElement(indices: indices, primitiveType: .triangles)
            }

            let material = try primitive.material?.resolve(in: document)
            let scnMaterial = try material.map { try generateSCNMaterial(from: $0) }

            return PrimitiveGeometry(sources: sources, element: scnElement, materials: [scnMaterial].compactMap { $0 })
        }

        let sources = sourcesAndElements.flatMap(\.sources)
        let elements = sourcesAndElements.compactMap(\.element)
        let materials = sourcesAndElements.flatMap(\.materials)

        let geometry = SCNGeometry(sources: sources, elements: elements)
        geometry.materials = materials
        return geometry
    }

    func generateSCNMaterial(from material: Material) throws -> SCNMaterial {
        let scnMaterial = SCNMaterial()

        if let pbrMetallicRoughness = material.pbrMetallicRoughness {
            scnMaterial.lightingModel = material.isUnlit ? .constant : .physicallyBased
            let textured = try pbrMetallicRoughness.baseColorTexture.map {
                try configureSCNMaterialProperty(property: scnMaterial.diffuse, from: $0)
            } ?? false
            if !textured {
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
            scnMaterial.normal.intensity = CGFloat(normalTexture.normalScale)
        }

        if let occlusionTexture = material.occlusionTexture {
            // glTF occlusion lives in the R channel.
            try configureSCNMaterialProperty(property: scnMaterial.ambientOcclusion, channel: .red, from: occlusionTexture)
            scnMaterial.ambientOcclusion.intensity = CGFloat(occlusionTexture.occlusionStrength)
        }

        if let emissiveTexture = material.emissiveTexture {
            // glTF emissive = emissiveFactor * emissiveTexture; bake a non-white factor in.
            let factor = material.emissiveFactor ?? [1, 1, 1]
            try configureSCNMaterialProperty(
                property: scnMaterial.emission,
                from: emissiveTexture,
                tint: factor == [1, 1, 1] ? nil : factor
            )
        }
        else if let emissiveFactor = material.emissiveFactor {
            scnMaterial.emission.contents = SIMD4<Float>(emissiveFactor.x, emissiveFactor.y, emissiveFactor.z, 1).cgColor
        }
        // KHR_materials_emissive_strength multiplies the emissive output.
        scnMaterial.emission.intensity = CGFloat(material.emissiveStrength)

        scnMaterial.isDoubleSided = material.doubleSided ?? false

        switch material.alphaMode ?? .OPAQUE {
        case .OPAQUE:
            scnMaterial.blendMode = .replace
            scnMaterial.writesToDepthBuffer = true
        case .MASK:
            // SceneKit has no alpha cutoff; approximate by clipping in a shader modifier.
            let cutoff = material.alphaCutoff ?? 0.5
            scnMaterial.blendMode = .replace
            scnMaterial.writesToDepthBuffer = true
            scnMaterial.shaderModifiers = [
                .fragment: "if (_output.color.a < \(cutoff)) { discard_fragment(); }"
            ]
        case .BLEND:
            scnMaterial.blendMode = .alpha
            scnMaterial.writesToDepthBuffer = false
        }

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

    // Returns false when the texture has no image we can load (it is skipped).
    @discardableResult
    func configureSCNMaterialProperty(
        property: SCNMaterialProperty,
        channel: Channel? = nil,
        from textureInfo: TextureInfo,
        tint: SIMD3<Float>? = nil
    ) throws -> Bool {
        let texture = try textureInfo.index.resolve(in: document)
        let sampler = try texture.sampler?.resolve(in: document) ?? Sampler()
        guard let source = try texture.source?.resolve(in: document) else {
            // The image comes from an extension (e.g. KHR_texture_basisu) we don't support.
            warning("Texture \(textureInfo.index.index) has no source image; skipping")
            return false
        }
        let baseImage: CGImage = try {
            let cgImage = try CGImage.load(data: imageData(for: source))
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
        let cgImage = try tint.map { try baseImage.multiplied(by: $0) } ?? baseImage

        property.contents = cgImage
        property.mappingChannel = textureInfo.texCoord // 0 = TEXCOORD_0, 1 = TEXCOORD_1
        property.wrapS = SCNWrapMode(sampler.wrapS)
        property.wrapT = SCNWrapMode(sampler.wrapT)
        if let magfilter = sampler.magFilter.map(SCNFilterMode.init) {
            property.magnificationFilter = magfilter
        }
        if let minfilter = sampler.minFilter.map(SCNFilterMode.init) {
            property.minificationFilter = minfilter
        }
        if let transform = textureInfo.textureTransform {
            property.contentsTransform = SCNMatrix4(textureTransform: transform)
        }
        return true
    }
}

extension CGImage {
    static func load(data: Data) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw GLTFError.unknown
        }
        return image
    }
}

// MARK: -

extension SCNFilterMode {
    init(filter: Sampler.MagFilter) {
        switch filter {
        case .LINEAR:
            self = .linear
        case .NEAREST:
            self = .nearest
        }
    }
}

extension SCNFilterMode {
    init(filter: Sampler.MinFilter) {
        switch filter {
        case .LINEAR:
            self = .linear
        case .NEAREST:
            self = .nearest
        default:
            warning("No filter \(filter)")
            self = .linear
        }
    }
}

extension SCNWrapMode {
    init(_ mode: Sampler.Wrap) {
        switch mode {
        case .CLAMP_TO_EDGE:
            self = .clamp // .clampToBorder would sample the border color
        case .MIRRORED_REPEAT:
            self = .mirror
        case .REPEAT:
            self = .repeat
        }
    }
}

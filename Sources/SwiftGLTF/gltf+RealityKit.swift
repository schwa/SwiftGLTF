// swiftlint:disable type_body_length

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
import CoreImage
import Foundation
import RealityKit

// RealityKit entities, components and resources are main-actor isolated.
@MainActor
public class RealityKitGLTFGenerator {
    let container: Container?
    let document: Document

    public init(container: Container) {
        self.container = container
        self.document = container.document
    }

    public init(document: Document) {
        self.container = nil
        self.document = document
    }

    private func requireContainer() throws -> Container {
        guard let container else {
            throw GLTFError.missingResource("This operation needs buffer data; construct the generator with a Container")
        }
        return container
    }

    public func generateRootEntity() throws -> Entity {
        let rootEntity = Entity()
        // 'scenes' is optional in glTF; with none there is nothing to show.
        guard let scene = try document.scene.map({ try $0.resolve(in: document) }) ?? document.scenes.first else {
            return rootEntity
        }
        try scene.nodes
            .map { try $0.resolve(in: document) }
            .map { try generateEntity(from: $0) }
            .forEach {
                rootEntity.addChild($0)
            }
        return rootEntity
    }

    func generateEntity(from node: Node) throws -> Entity {
        let entity = Entity()

        if let mesh = try node.mesh?.resolve(in: document) {
            entity.components[ModelComponent.self] = try generateMeshResource(from: mesh)
        }
        if let cameraIndex = node.camera {
            let camera = try cameraIndex.resolve(in: document)
            switch camera.type {
            case .perspective:
                var component = PerspectiveCameraComponent()
                if let perspective = camera.perspective {
                    component.fieldOfViewInDegrees = perspective.yfov * 180 / .pi
                    component.near = perspective.znear
                    if let zfar = perspective.zfar {
                        component.far = zfar
                    }
                }
                entity.components.set(component)
            case .orthographic:
                // RealityKit has no public orthographic camera component.
                warning("Orthographic cameras are not supported by the RealityKit generator")
            }
        }
        if let light = node.punctualLight(in: document) {
            applyLight(light, to: entity)
        }
        if let matrix = node.matrix {
            entity.transform.matrix = matrix
        }
        if let translation = node.translation {
            entity.transform.translation = translation
        }
        if let rotation = node.rotation {
            entity.transform.rotation = simd_quatf(vector: rotation)
        }
        if let scale = node.scale {
            entity.transform.scale = scale
        }
        try node.children.map { try $0.resolve(in: document) }.map { try generateEntity(from: $0) }.forEach {
            entity.addChild($0)
        }
        return entity
    }

    func applyLight(_ light: Light, to entity: Entity) {
        #if os(macOS)
        let color = NSColor(
            red: Double(light.color.x),
            green: Double(light.color.y),
            blue: Double(light.color.z),
            alpha: 1
        )
        #else
        let color = UIColor(
            red: Double(light.color.x),
            green: Double(light.color.y),
            blue: Double(light.color.z),
            alpha: 1
        )
        #endif
        switch light.type {
        case .directional:
            entity.components.set(DirectionalLightComponent(color: color, intensity: light.intensity))
        case .point:
            entity.components.set(PointLightComponent(color: color, intensity: light.intensity))
        case .spot:
            let inner = (light.spot?.innerConeAngle ?? 0) * 180 / .pi
            let outer = (light.spot?.outerConeAngle ?? .pi / 4) * 180 / .pi
            entity.components.set(SpotLightComponent(
                color: color,
                intensity: light.intensity,
                innerAngleInDegrees: inner,
                outerAngleInDegrees: outer
            ))
        }
    }

    func generateMeshResource(from mesh: Mesh) throws -> ModelComponent {
        var descriptors: [MeshDescriptor] = []
        var materials: [RealityKit.Material] = []
        for (index, primitive) in mesh.primitives.enumerated() {
            var descriptor = try meshDescriptor(from: primitive)
            descriptor.materials = .allFaces(UInt32(index))
            descriptors.append(descriptor)
            materials.append(try reMaterial(for: primitive))
        }
        let meshResource = try MeshResource.generate(from: descriptors)
        return ModelComponent(mesh: meshResource, materials: materials)
    }

    private func meshDescriptor(from primitive: Mesh.Primitive) throws -> MeshDescriptor {
        let container = try requireContainer()
        var meshDescriptor = MeshDescriptor()
        if let positions = try primitive.value(semantic: .POSITION, type: SIMD3<Float>.self, in: container) {
            meshDescriptor.positions = MeshBuffers.Positions(positions)
        }
        if let normals = try primitive.value(semantic: .NORMAL, type: SIMD3<Float>.self, in: container) {
            meshDescriptor.normals = MeshBuffers.Normals(normals)
        }
        if let tangents = try primitive.value(semantic: .TANGENT, type: SIMD4<Float>.self, in: container) {
            meshDescriptor.tangents = MeshBuffers.Tangents(tangents.map(\.xyz))
        }
        if let textureCoordinates = try primitive.value(semantic: .TEXCOORD_0, type: SIMD2<Float>.self, in: container) {
            meshDescriptor.textureCoordinates = MeshBuffers.TextureCoordinates(textureCoordinates)
        }
        if primitive.attributes[.COLOR_0] != nil {
            warning("Vertex colors (COLOR_0) are not supported by the RealityKit generator")
        }
        if primitive.attributes[.TEXCOORD_1] != nil {
            warning("A second UV set (TEXCOORD_1) is not supported by the RealityKit generator")
        }
        guard primitive.mode == .TRIANGLES else {
            throw GLTFError.unsupported("Unsupported primitive mode \(primitive.mode)")
        }
        if let indices = try primitive.indices(type: UInt32.self, in: container) {
            meshDescriptor.primitives = .triangles(indices)
        }
        else if let positions = try primitive.attributes[.POSITION]?.resolve(in: container.document) {
            // Non-indexed: vertices are drawn in order.
            meshDescriptor.primitives = .triangles(Array(0 ..< UInt32(positions.count)))
        }
        return meshDescriptor
    }

    private func reMaterial(for primitive: Mesh.Primitive) throws -> RealityKit.Material {
        // glTF: a primitive with no material uses the default material.
        if let material = try primitive.material?.resolve(in: document) {
            return try makeMaterial(from: material)
        }
        return PhysicallyBasedMaterial()
    }

    private enum TextureChannel {
        case red
        case green
        case blue
    }

    private func texture(
        from info: TextureInfo,
        semantic: TextureResource.Semantic,
        channel: TextureChannel? = nil,
        tint: SIMD3<Float>? = nil,
        adjust: ((CGImage) throws -> CGImage)? = nil
    ) throws -> MaterialParameters.Texture? {
        if info.textureTransform != nil {
            // PhysicallyBasedMaterial has no public per-texture UV transform.
            warning("KHR_texture_transform is not supported by the RealityKit generator")
        }
        let texture = try info.index.resolve(in: document)
        guard let source = try texture.source?.resolve(in: document) else {
            // The image comes from an extension (e.g. KHR_texture_basisu) we don't support.
            warning("Texture \(info.index.index) has no source image; skipping")
            return nil
        }
        let data = try requireContainer().data(for: source)
        var image = try CGImage.image(with: data)
        switch channel {
        case .red: image = image.redChannel
        case .green: image = image.greenChannel
        case .blue: image = image.blueChannel
        case .none: break
        }
        if let tint {
            image = try image.multiplied(by: tint)
        }
        if let adjust {
            image = try adjust(image)
        }
        let resource = try TextureResource(image: image, options: .init(semantic: semantic))
        return MaterialParameters.Texture(resource)
    }

    func makeMaterial(from material: Material) throws -> RealityKit.Material {
        if material.isUnlit {
            var unlit = UnlitMaterial()
            if let pbrMetallicRoughness = material.pbrMetallicRoughness {
                var baseColorTexture: MaterialParameters.Texture?
                if let textureInfo = pbrMetallicRoughness.baseColorTexture {
                    baseColorTexture = try texture(from: textureInfo, semantic: .color)
                }
                unlit.color = .init(tint: color(pbrMetallicRoughness.baseColorFactor), texture: baseColorTexture)
            }
            return unlit
        }

        var reMaterial = PhysicallyBasedMaterial()
        if let pbrMetallicRoughness = material.pbrMetallicRoughness {
            let rgba = pbrMetallicRoughness.baseColorFactor
            var baseColorTexture: MaterialParameters.Texture?
            if let textureInfo = pbrMetallicRoughness.baseColorTexture {
                baseColorTexture = try texture(from: textureInfo, semantic: .color)
            }
            let tint = color(rgba)
            reMaterial.baseColor = .init(tint: tint, texture: baseColorTexture)

            // glTF packs roughness in G and metallic in B of one texture.
            if let mrTexture = pbrMetallicRoughness.metallicRoughnessTexture,
               let roughness = try texture(from: mrTexture, semantic: .raw, channel: .green),
               let metallic = try texture(from: mrTexture, semantic: .raw, channel: .blue) {
                reMaterial.roughness = .init(scale: pbrMetallicRoughness.roughnessFactor, texture: roughness)
                reMaterial.metallic = .init(scale: pbrMetallicRoughness.metallicFactor, texture: metallic)
            }
            else {
                reMaterial.roughness = .init(floatLiteral: pbrMetallicRoughness.roughnessFactor)
                reMaterial.metallic = .init(floatLiteral: pbrMetallicRoughness.metallicFactor)
            }
        }

        // RealityKit has no normal-scale / occlusion-strength parameters, so bake
        // them into the texture when they differ from the default 1.
        if let normalInfo = material.normalTexture {
            let scale = normalInfo.normalScale
            if let normal = try texture(
                from: normalInfo,
                semantic: .normal,
                adjust: scale == 1 ? nil : { try $0.normalScaled(by: scale) }
            ) {
                reMaterial.normal = .init(texture: normal)
            }
        }

        if let occlusionInfo = material.occlusionTexture {
            let strength = occlusionInfo.occlusionStrength
            if let occlusion = try texture(
                from: occlusionInfo,
                semantic: .raw,
                channel: .red,
                adjust: strength == 1 ? nil : { try $0.occlusionAdjusted(strength: strength) }
            ) {
                reMaterial.ambientOcclusion = .init(texture: occlusion)
            }
        }

        let emissiveFactor = material.emissiveFactor ?? [0, 0, 0]
        // glTF emissive = emissiveFactor * emissiveTexture. RealityKit's
        // EmissiveColor(color:texture:) does not multiply this way (a white
        // color makes the whole surface glow), so pass the texture alone and
        // bake a non-white factor into it.
        let emissiveTint: SIMD3<Float>? = emissiveFactor == [1, 1, 1] ? nil : emissiveFactor
        if let emissiveInfo = material.emissiveTexture,
           let emissive = try texture(from: emissiveInfo, semantic: .color, tint: emissiveTint) {
            reMaterial.emissiveColor = .init(texture: emissive)
            reMaterial.emissiveIntensity = material.emissiveStrength // KHR_materials_emissive_strength
        }
        else if emissiveFactor != [0, 0, 0] {
            let emissiveColor = color(SIMD4<Float>(emissiveFactor.x, emissiveFactor.y, emissiveFactor.z, 1))
            reMaterial.emissiveColor = .init(color: emissiveColor)
            reMaterial.emissiveIntensity = material.emissiveStrength
        }

        if material.doubleSided ?? false {
            reMaterial.faceCulling = .none
        }

        switch material.alphaMode ?? .OPAQUE {
        case .OPAQUE:
            reMaterial.blending = .opaque
        case .MASK:
            reMaterial.opacityThreshold = material.alphaCutoff ?? 0.5
        case .BLEND:
            reMaterial.blending = .transparent(opacity: .init(floatLiteral: 1))
        }

        return reMaterial
    }

    #if os(macOS)
    private func color(_ rgba: SIMD4<Float>) -> NSColor {
        NSColor(red: Double(rgba[0]), green: Double(rgba[1]), blue: Double(rgba[2]), alpha: Double(rgba[3]))
    }
    #else
    private func color(_ rgba: SIMD4<Float>) -> UIColor {
        UIColor(red: Double(rgba[0]), green: Double(rgba[1]), blue: Double(rgba[2]), alpha: Double(rgba[3]))
    }
    #endif
}

extension CGImage {
    static func image(with data: Data) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw GLTFError.unsupported("Image data could not be decoded (\(data.count) bytes)")
        }
        return image
    }
}

extension Mesh.Primitive {
    func value(semantic: Mesh.Primitive.Semantic, type: SIMD2<Float>.Type, in container: Container) throws -> [SIMD2<Float>]? {
        try vectors(semantic, componentCount: 2, in: container) { SIMD2($0[0], $0[1]) }
    }

    func value(semantic: Mesh.Primitive.Semantic, type: SIMD3<Float>.Type, in container: Container) throws -> [SIMD3<Float>]? {
        try vectors(semantic, componentCount: 3, in: container) { SIMD3($0[0], $0[1], $0[2]) }
    }

    func value(semantic: Mesh.Primitive.Semantic, type: SIMD4<Float>.Type, in container: Container) throws -> [SIMD4<Float>]? {
        try vectors(semantic, componentCount: 4, in: container) { SIMD4($0[0], $0[1], $0[2], $0[3]) }
    }

    // Reads any component type through floatComponents, which handles byte
    // strides and the normalized flag (e.g. normalized UNSIGNED_BYTE texcoords).
    private func vectors<V>(
        _ semantic: Semantic,
        componentCount: Int,
        in container: Container,
        make: ([Float]) -> V
    ) throws -> [V]? {
        guard let accessor = try attributes[semantic]?.resolve(in: container.document) else {
            return nil
        }
        guard accessor.type.componentCount == componentCount else {
            throw GLTFError.unsupported("\(semantic.rawValue) is \(accessor.type), expected \(componentCount) components")
        }
        let floats = try container.floatComponents(for: accessor)
        return stride(from: 0, to: floats.count, by: componentCount).map { start in
            make(Array(floats[start ..< start + componentCount]))
        }
    }

    func indices(type: UInt32.Type, in container: Container) throws -> [UInt32]? {
        guard let indicesAccessor = try indices?.resolve(in: container.document) else {
            return nil // non-indexed: the caller draws vertices in order
        }
        switch indicesAccessor.componentType {
        case .UNSIGNED_BYTE:
            let indices = [UInt8](try container.data(for: indicesAccessor))
            assert(indicesAccessor.min == nil || indicesAccessor.max == nil || indices.allSatisfy({ (UInt8(indicesAccessor.min![0]) ... UInt8(indicesAccessor.max![0])).contains($0) }))
            assert(indices.count == indicesAccessor.count)
            return indices.map { UInt32($0) }
        case .UNSIGNED_SHORT:
            let indices = [UInt16](withUnsafeData: try container.data(for: indicesAccessor))
            assert(indicesAccessor.min == nil || indicesAccessor.max == nil || indices.allSatisfy({ (UInt16(indicesAccessor.min![0]) ... UInt16(indicesAccessor.max![0])).contains($0) }))
            assert(indices.count == indicesAccessor.count)
            return indices.map { UInt32($0) }
        case .UNSIGNED_INT:
            let indices = [UInt32](withUnsafeData: try container.data(for: indicesAccessor))
            assert(indicesAccessor.min == nil || indicesAccessor.max == nil || indices.allSatisfy({ (UInt32(indicesAccessor.min![0]) ... UInt32(indicesAccessor.max![0])).contains($0) }))
            assert(indices.count == indicesAccessor.count)
            return indices
        default:
            throw GLTFError.unsupported("Unsupported index component type \(indicesAccessor.componentType)")
        }
    }
}

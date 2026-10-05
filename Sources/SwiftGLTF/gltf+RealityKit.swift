#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
import CoreImage
import Foundation
import RealityKit

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
        let scene = try document.scene.map { try $0.resolve(in: document) } ?? document.scenes.first!
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
        if let indices = try primitive.indices(type: UInt32.self, in: container) {
            assert(primitive.mode == .TRIANGLES)
            meshDescriptor.primitives = .triangles(indices)
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
        channel: TextureChannel? = nil
    ) throws -> MaterialParameters.Texture {
        let texture = try info.index.resolve(in: document)
        let source = try texture.source!.resolve(in: document)
        let data = try requireContainer().data(for: source)
        var image = try CGImage.image(with: data)
        switch channel {
        case .red: image = image.redChannel
        case .green: image = image.greenChannel
        case .blue: image = image.blueChannel
        case .none: break
        }
        let resource = try TextureResource.generate(from: image, options: .init(semantic: semantic))
        return MaterialParameters.Texture(resource)
    }

    func makeMaterial(from material: Material) throws -> RealityKit.Material {
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
            if let mrTexture = pbrMetallicRoughness.metallicRoughnessTexture {
                reMaterial.roughness = .init(
                    scale: pbrMetallicRoughness.roughnessFactor,
                    texture: try texture(from: mrTexture, semantic: .raw, channel: .green)
                )
                reMaterial.metallic = .init(
                    scale: pbrMetallicRoughness.metallicFactor,
                    texture: try texture(from: mrTexture, semantic: .raw, channel: .blue)
                )
            }
            else {
                reMaterial.roughness = .init(floatLiteral: pbrMetallicRoughness.roughnessFactor)
                reMaterial.metallic = .init(floatLiteral: pbrMetallicRoughness.metallicFactor)
            }
        }

        if let normalInfo = material.normalTexture {
            reMaterial.normal = .init(texture: try texture(from: normalInfo, semantic: .normal))
        }

        if let occlusionInfo = material.occlusionTexture {
            reMaterial.ambientOcclusion = .init(
                texture: try texture(from: occlusionInfo, semantic: .raw, channel: .red)
            )
        }

        let emissiveFactor = material.emissiveFactor ?? [0, 0, 0]
        var emissiveTexture: MaterialParameters.Texture?
        if let emissiveInfo = material.emissiveTexture {
            emissiveTexture = try texture(from: emissiveInfo, semantic: .color)
        }
        if emissiveTexture != nil || emissiveFactor != [0, 0, 0] {
            let emissiveColor = color(SIMD4<Float>(emissiveFactor.x, emissiveFactor.y, emissiveFactor.z, 1))
            reMaterial.emissiveColor = .init(color: emissiveColor, texture: emissiveTexture)
            reMaterial.emissiveIntensity = 1
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

extension Container {
    func data(for image: Image) throws -> Data {
        if let uri = image.uri {
            return try data(for: uri)
        }
        else if let bufferView = try image.bufferView?.resolve(in: document) {
            return try data(for: bufferView)
        }
        else {
            throw GLTFError.missingResource("Image has neither uri nor bufferView")
        }
    }
}

extension CGImage {
    static func image(with data: Data) throws -> CGImage {
        let source = CGImageSourceCreateWithData(data as CFData, nil)!
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        return image!
    }
}

extension Mesh.Primitive {
    func value(semantic: Mesh.Primitive.Semantic, type: SIMD2<Float>.Type, in container: Container) throws -> [SIMD2<Float>]? {
        guard let accessor = try attributes[semantic]?.resolve(in: container.document) else {
            return nil
        }
        assert(accessor.componentType == .FLOAT)
        let values = [SIMD2<Float>](withUnsafeData: try container.data(for: accessor))
        assert(values.count == accessor.count)
        assert(accessor.min == nil || accessor.max == nil || values.allSatisfy({ $0.within(min: SIMD2<Float>(accessor.min!), max: SIMD2<Float>(accessor.max!)) }))
        return values
    }

    func value(semantic: Mesh.Primitive.Semantic, type: SIMD3<Float>.Type, in container: Container) throws -> [SIMD3<Float>]? {
        guard let accessor = try attributes[semantic]?.resolve(in: container.document) else {
            return nil
        }

        struct FauxVector3 {
            var x: Float
            var y: Float
            var z: Float
        }

        let values: [SIMD3<Float>]
        switch accessor.componentType {
        case .FLOAT:
            values = [FauxVector3](withUnsafeData: try container.data(for: accessor)).map {
                SIMD3<Float>($0.x, $0.y, $0.z)
            }
        case .UNSIGNED_SHORT:
            values = [SIMD3<Float>](withUnsafeData: try container.data(for: accessor)).map { SIMD3<Float>($0.map { Float($0) }) }
        default:
            throw GLTFError.unsupported("Unsupported SIMD3 component type \(accessor.componentType)")
        }

        assert(values.count == accessor.count)
        // assert(accessor.min == nil || accessor.max == nil || values.allSatisfy({ $0.within(min: SIMD3<Float>(accessor.min!), max: SIMD3<Float>(accessor.max!)) }))
        return values
    }

    func value(semantic: Mesh.Primitive.Semantic, type: SIMD4<Float>.Type, in container: Container) throws -> [SIMD4<Float>]? {
        guard let accessor = try attributes[semantic]?.resolve(in: container.document) else {
            return nil
        }
        assert(accessor.componentType == .FLOAT)
        let values = [SIMD4<Float>](withUnsafeData: try container.data(for: accessor))
        assert(values.count == accessor.count)
        assert(accessor.min == nil || accessor.max == nil || values.allSatisfy({ $0.within(min: SIMD4<Float>(accessor.min!), max: SIMD4<Float>(accessor.max!)) }))
        return values
    }

    func indices(type: UInt32.Type, in container: Container) throws -> [UInt32]? {
        guard let indicesAccessor = try indices?.resolve(in: container.document) else {
            throw GLTFError.missingResource("Primitive has no indices")
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

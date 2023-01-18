#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
import CoreImage
import Foundation
import RealityKit

public class RealityKitGLTFGenerator {
    let container: Container

    public init(container: Container) {
        self.container = container
    }

    var document: Document {
        container.document
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

    func generateMeshResource(from mesh: Mesh) throws -> ModelComponent {
        // assert(mesh.primitives.count == 1)
        let primitive = mesh.primitives.first!

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
        let meshResource = try MeshResource.generate(from: [meshDescriptor])

        guard let material = try primitive.material?.resolve(in: document) else {
            fatalError()
        }
        let reMaterial = try makeMaterial(from: material)
        return ModelComponent(mesh: meshResource, materials: [reMaterial])
    }

    func makeMaterial(from material: Material) throws -> RealityKit.Material {
        var reMaterial = PhysicallyBasedMaterial()
        if let pbrMetallicRoughness = material.pbrMetallicRoughness {
            let rgba = pbrMetallicRoughness.baseColorFactor.map {
                CGFloat($0)
            }
            var reTexture: MaterialParameters.Texture?
            if let textureInfo = pbrMetallicRoughness.baseColorTexture {
                let texture = try textureInfo.index.resolve(in: document)
                let source = try texture.source!.resolve(in: document)
                let data = try container.data(for: source)
                let image = try CGImage.image(with: data)
                let textureResource = try TextureResource.generate(from: image, options: .init(semantic: .color))
                reTexture = MaterialParameters.Texture(textureResource)
            }
            #if os(macOS)
            reMaterial.baseColor = .init(tint: NSColor(red: rgba[0], green: rgba[1], blue: rgba[2], alpha: rgba[3]), texture: reTexture)
            #elseif os(iOS)
            reMaterial.baseColor = .init(tint: UIColor(red: rgba[0], green: rgba[1], blue: rgba[2], alpha: rgba[3]), texture: reTexture)
            #endif
        }
        return reMaterial
    }
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
            fatalError()
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
        let values = Array <SIMD2<Float>>(withUnsafeData: try container.data(for: accessor))
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
            values = Array <FauxVector3>(withUnsafeData: try container.data(for: accessor)).map {
                SIMD3<Float>($0.x, $0.y, $0.z)
            }
        case .UNSIGNED_SHORT:
            values = Array <SIMD3<Float>>(withUnsafeData: try container.data(for: accessor)).map { SIMD3<Float>($0.map { Float($0) }) }
        default:
            fatalError()
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
        let values = Array <SIMD4<Float>>(withUnsafeData: try container.data(for: accessor))
        assert(values.count == accessor.count)
        assert(accessor.min == nil || accessor.max == nil || values.allSatisfy({ $0.within(min: SIMD4<Float>(accessor.min!), max: SIMD4<Float>(accessor.max!)) }))
        return values
    }

    func indices(type: UInt32.Type, in container: Container) throws -> [UInt32]? {
        guard let indicesAccessor = try indices?.resolve(in: container.document) else {
            fatalError()
        }
        switch indicesAccessor.componentType {
        case .UNSIGNED_BYTE:
            let indices = [UInt8](try container.data(for: indicesAccessor))
            assert(indicesAccessor.min == nil || indicesAccessor.max == nil || indices.allSatisfy({ (UInt8(indicesAccessor.min![0]) ... UInt8(indicesAccessor.max![0])).contains($0) }))
            assert(indices.count == indicesAccessor.count)
            return indices.map { UInt32($0) }
        case .UNSIGNED_SHORT:
            let indices = Array <UInt16>(withUnsafeData: try container.data(for: indicesAccessor))
            assert(indicesAccessor.min == nil || indicesAccessor.max == nil || indices.allSatisfy({ (UInt16(indicesAccessor.min![0]) ... UInt16(indicesAccessor.max![0])).contains($0) }))
            assert(indices.count == indicesAccessor.count)
            return indices.map { UInt32($0) }
        case .UNSIGNED_INT:
            let indices = Array <UInt32>(withUnsafeData: try container.data(for: indicesAccessor))
            assert(indicesAccessor.min == nil || indicesAccessor.max == nil || indices.allSatisfy({ (UInt32(indicesAccessor.min![0]) ... UInt32(indicesAccessor.max![0])).contains($0) }))
            assert(indices.count == indicesAccessor.count)
            return indices
        default:
            fatalError()
        }
    }
}

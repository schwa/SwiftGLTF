import Foundation
import SwiftGLTF
import Testing

// Non-testable import: a consumer builds a triangle from scratch and saves it (#72).
struct AuthoringTests {
    let positions: [Float] = [0, 0, 0, 1, 0, 0, 0, 1, 0]
    let indices: [UInt16] = [0, 1, 2]

    func makeContainer() throws -> Container {
        var binary = positions.withUnsafeBytes { Data($0) }
        let indexOffset = binary.count
        binary += indices.withUnsafeBytes { Data($0) }
        let document = Document(
            asset: Asset(generator: "AuthoringTests"),
            scene: Index(0),
            scenes: [Scene(nodes: [Index(0)])],
            nodes: [Node(name: "triangle", mesh: Index(0))],
            meshes: [Mesh(primitives: [.init(attributes: [.POSITION: Index(0)], indices: Index(1), material: Index(0))])],
            accessors: [
                Accessor(bufferView: Index(0), componentType: .FLOAT, count: 3, type: .VEC3, max: [1, 1, 0], min: [0, 0, 0]),
                Accessor(bufferView: Index(1), componentType: .UNSIGNED_SHORT, count: 3, type: .SCALAR)
            ],
            bufferViews: [
                BufferView(buffer: Index(0), byteLength: indexOffset, target: .ARRAY_BUFFER),
                BufferView(buffer: Index(0), byteOffset: indexOffset, byteLength: binary.count - indexOffset, target: .ELEMENT_ARRAY_BUFFER)
            ],
            buffers: [Buffer(byteLength: binary.count)],
            materials: [Material(pbrMetallicRoughness: .init(baseColorFactor: [1, 0, 0, 1]))]
        )
        return try Container(document: document, binaryBuffer: binary)
    }

    @Test(arguments: ["glb", "gltf"])
    func writesAndReloads(pathExtension: String) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("triangle.\(pathExtension)")
        try makeContainer().write(to: url)

        let loaded = try Container(url: url)
        #expect(try loaded.validate().isEmpty)
        let document = loaded.document
        #expect(document.asset.generator == "AuthoringTests")
        #expect(document.nodes.map(\.name) == ["triangle"])
        #expect(document.materials.first?.pbrMetallicRoughness?.baseColorFactor == [1, 0, 0, 1])
        let primitive = try #require(document.meshes.first?.primitives.first)
        let positionAccessor = try #require(primitive.attributes[.POSITION]).resolve(in: document)
        let indexAccessor = try #require(primitive.indices).resolve(in: document)
        #expect(try loaded.data(for: positionAccessor) == positions.withUnsafeBytes { Data($0) })
        #expect(try loaded.data(for: indexAccessor) == indices.withUnsafeBytes { Data($0) })
    }
}

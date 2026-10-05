#if os(macOS)
import CoreGraphics
import Foundation
import ImageIO
import SceneKit
import Testing
import UniformTypeIdentifiers

@testable import SwiftGLTF

// glTF URIs are RFC 3986 encoded: "my%20buffer.bin" names the file "my buffer.bin" (#45).
struct PercentEncodedURITests {
    // A .gltf whose buffer and image live in files with spaces in their names.
    private func makeModel() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("uri-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let positions: [Float] = [0, 0, 0, 1, 0, 0, 0, 1, 0]
        try positions.withUnsafeBufferPointer { Data(buffer: $0) }
            .write(to: directory.appendingPathComponent("my buffer.bin"))

        let context = try #require(CGContext(
            data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        let pngURL = directory.appendingPathComponent("my texture.png")
        let destination = try #require(CGImageDestinationCreateWithURL(pngURL as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try #require(context.makeImage()), nil)
        CGImageDestinationFinalize(destination)

        let json = """
        {
          "asset": { "version": "2.0" },
          "buffers": [ { "byteLength": 36, "uri": "my%20buffer.bin" } ],
          "bufferViews": [ { "buffer": 0, "byteLength": 36 } ],
          "accessors": [ { "bufferView": 0, "componentType": 5126, "count": 3, "type": "VEC3" } ],
          "images": [ { "uri": "my%20texture.png" } ],
          "textures": [ { "source": 0 } ],
          "materials": [ { "pbrMetallicRoughness": { "baseColorTexture": { "index": 0 } } } ],
          "meshes": [ { "primitives": [ { "attributes": { "POSITION": 0 }, "material": 0 } ] } ],
          "nodes": [ { "mesh": 0 } ],
          "scenes": [ { "nodes": [0] } ],
          "scene": 0
        }
        """
        let url = directory.appendingPathComponent("model.gltf")
        try Data(json.utf8).write(to: url)
        return url
    }

    @Test
    func containerLoadsPercentEncodedBufferAndImage() throws {
        let container = try Container(url: makeModel())
        #expect(try container.data(for: container.document.buffers[0]).count == 36)
        #expect(try !container.data(for: container.document.images[0]).isEmpty)
    }

    @Test
    func sceneKitLoadsPercentEncodedResources() throws {
        let container = try Container(url: makeModel())
        let scene = try SceneKitGenerator(container: container).generateSCNScene()
        #expect(scene.rootNode.childNodes.isEmpty == false)
    }

    @Test
    func writerCopiesPercentEncodedFiles() throws {
        let container = try Container(url: makeModel())
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("uri-out-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try container.write(to: output.appendingPathComponent("copy.gltf"), embedResources: false)
        #expect(FileManager.default.fileExists(atPath: output.appendingPathComponent("my buffer.bin").path))
        #expect(FileManager.default.fileExists(atPath: output.appendingPathComponent("my texture.png").path))
        // And the copy loads.
        let reloaded = try Container(url: output.appendingPathComponent("copy.gltf"))
        #expect(try reloaded.data(for: reloaded.document.buffers[0]).count == 36)
    }
}
#endif

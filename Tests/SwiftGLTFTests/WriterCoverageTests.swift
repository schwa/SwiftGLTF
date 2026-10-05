import Foundation
import Testing

@testable import SwiftGLTF

struct WriterCoverageTests {
    private func glbContainer() throws -> Container {
        let positions: [Float] = [0, 0, 0, 1, 0, 0, 0, 1, 0]
        let json = Data(#"""
        {"asset":{"version":"2.0"},"buffers":[{"byteLength":36}],
         "bufferViews":[{"buffer":0,"byteLength":36}],
         "accessors":[{"bufferView":0,"componentType":5126,"count":3,"type":"VEC3"}]}
        """#.utf8)
        let url = try TestSupport.temporaryDirectory().appendingPathComponent("source.glb")
        try GLTFWriter.glbData(json: json, binary: TestSupport.bytes(positions)).write(to: url)
        return try Container(url: url)
    }

    // GLB -> glTF without embedding writes the BIN chunk as a sidecar .bin.
    @Test
    func glbToExternalGLTFWritesSidecar() throws {
        let original = try glbContainer()
        let output = try TestSupport.temporaryDirectory().appendingPathComponent("out.gltf")
        try original.write(to: output, embedResources: false)
        let sidecar = output.deletingLastPathComponent().appendingPathComponent("out.bin")
        #expect(FileManager.default.fileExists(atPath: sidecar.path))
        let reloaded = try Container(url: output)
        #expect(reloaded.document.buffers[0].uri?.string == "out.bin")
        #expect(try reloaded.data(for: reloaded.document.accessors[0]) == original.data(for: original.document.accessors[0]))
    }

    // External images are embedded as data URIs; the MIME type comes from
    // mimeType, else the file extension.
    @Test
    func externalImagesAreEmbedded() throws {
        let directory = try TestSupport.temporaryDirectory()
        let png = TestSupport.png(red: 1, green: 0, blue: 0)
        try png.write(to: directory.appendingPathComponent("a.png"))
        try png.write(to: directory.appendingPathComponent("b.jpg"))
        try png.write(to: directory.appendingPathComponent("c.bin"))
        let container = try TestSupport.container(json: """
        { "asset": { "version": "2.0" },
          "images": [ { "uri": "a.png" }, { "uri": "b.jpg" }, { "uri": "c.bin", "mimeType": "image/png" } ] }
        """, in: directory)
        let output = try TestSupport.temporaryDirectory().appendingPathComponent("embedded.gltf")
        try container.write(to: output, embedResources: true)
        let reloaded = try Container(url: output)
        let uris = reloaded.document.images.map { $0.uri?.string ?? "" }
        #expect(uris[0].hasPrefix("data:image/png;base64,"))
        #expect(uris[1].hasPrefix("data:image/jpeg;base64,"))
        #expect(uris[2].hasPrefix("data:image/png;base64,"))
        for index in 0 ..< 3 {
            #expect(try reloaded.data(for: reloaded.document.images[index]) == png)
        }
    }

    // Writing next to the source must not try to copy files onto themselves,
    // and writing twice must overwrite copied files.
    @Test
    func externalWritesInPlaceAndOverwrite() throws {
        let directory = try TestSupport.temporaryDirectory()
        try TestSupport.bytes([Float](repeating: 1, count: 3)).write(to: directory.appendingPathComponent("data.bin"))
        let container = try TestSupport.container(json: """
        { "asset": { "version": "2.0" }, "buffers": [ { "byteLength": 12, "uri": "data.bin" } ] }
        """, in: directory)
        try container.write(to: directory.appendingPathComponent("copy.gltf"), embedResources: false)
        #expect(try Container(url: directory.appendingPathComponent("copy.gltf")).data(for: container.document.buffers[0]).count == 12)

        let elsewhere = try TestSupport.temporaryDirectory()
        try container.write(to: elsewhere.appendingPathComponent("a.gltf"), embedResources: false)
        try container.write(to: elsewhere.appendingPathComponent("a.gltf"), embedResources: false)
        #expect(FileManager.default.fileExists(atPath: elsewhere.appendingPathComponent("data.bin").path))
    }

    @Test
    func documentWithoutBuffersWritesGLBWithoutBINChunk() throws {
        let container = try TestSupport.container(json: #"{ "asset": { "version": "2.0" }, "nodes": [ {} ] }"#)
        let output = try TestSupport.temporaryDirectory().appendingPathComponent("empty.glb")
        try container.write(to: output)
        let glb = try GLB(url: output)
        #expect(glb.chunks.count == 1)
        #expect(try Container(url: output).document.nodes.count == 1)
    }
}

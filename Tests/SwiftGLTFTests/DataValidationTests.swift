import Foundation
import Testing

@testable import SwiftGLTF

// Data-level validation (#42): needs buffer bytes, so it lives on Container.
struct DataValidationTests {
    // Writes a .gltf whose single buffer holds `floats` then `indices` (UInt16).
    private func container(floats: [Float], indices: [UInt16] = [], accessorsJSON: String, meshesJSON: String = "[]") throws -> Container {
        var bytes = floats.withUnsafeBufferPointer { Data(buffer: $0) }
        let indicesOffset = bytes.count
        bytes += indices.withUnsafeBufferPointer { Data(buffer: $0) }
        // The index bufferView is declared even when empty; keep it inside the buffer.
        bytes += Data(count: 2)
        while !bytes.count.isMultiple(of: 4) {
            bytes.append(0)
        }
        let json = """
        {
          "asset": { "version": "2.0" },
          "buffers": [ { "byteLength": \(bytes.count), "uri": "data:application/octet-stream;base64,\(bytes.base64EncodedString())" } ],
          "bufferViews": [
            { "buffer": 0, "byteLength": \(max(floats.count * 4, 4)) },
            { "buffer": 0, "byteOffset": \(indicesOffset), "byteLength": \(max(indices.count * 2, 2)) }
          ],
          "accessors": \(accessorsJSON),
          "meshes": \(meshesJSON)
        }
        """
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dv-\(UUID().uuidString).gltf")
        try Data(json.utf8).write(to: url)
        return try Container(url: url)
    }

    @Test
    func dataOutsideDeclaredBoundsIsAnError() throws {
        let container = try container(floats: [0, 2], accessorsJSON: """
        [ { "bufferView": 0, "componentType": 5126, "count": 2, "type": "SCALAR", "min": [0], "max": [1] } ]
        """)
        let issues = try container.validate()
        #expect(issues.contains { $0.severity == .error && $0.path == "/accessors/0/max" })
    }

    @Test
    func looserBoundsAreAWarning() throws {
        let container = try container(floats: [0, 1], accessorsJSON: """
        [ { "bufferView": 0, "componentType": 5126, "count": 2, "type": "SCALAR", "min": [-5], "max": [1] } ]
        """)
        let issues = try container.validate()
        #expect(issues.contains { $0.severity == .warning && $0.path == "/accessors/0/min" })
        #expect(!issues.contains { $0.severity == .error })
    }

    @Test
    func exactBoundsProduceNoIssues() throws {
        let container = try container(floats: [0, 1], accessorsJSON: """
        [ { "bufferView": 0, "componentType": 5126, "count": 2, "type": "SCALAR", "min": [0], "max": [1] } ]
        """)
        #expect(try container.validate().isEmpty)
    }

    @Test
    func outOfRangeIndexIsAnError() throws {
        // 3 vertices (VEC3 positions), index 5 is out of range.
        let container = try container(
            floats: [0, 0, 0, 1, 0, 0, 0, 1, 0],
            indices: [0, 1, 5],
            accessorsJSON: """
            [
              { "bufferView": 0, "componentType": 5126, "count": 3, "type": "VEC3" },
              { "bufferView": 1, "componentType": 5123, "count": 3, "type": "SCALAR" }
            ]
            """,
            meshesJSON: #"[ { "primitives": [ { "attributes": { "POSITION": 0 }, "indices": 1 } ] } ]"#
        )
        let issues = try container.validate()
        #expect(issues.contains { $0.severity == .error && $0.path == "/meshes/0/primitives/0/indices" })
    }

    @Test
    func textureInfoFieldsOnWrongSlotWarn() throws {
        let json = """
        { "asset": { "version": "2.0" }, "textures": [ {} ],
          "materials": [ { "pbrMetallicRoughness": { "baseColorTexture": { "index": 0, "scale": 2, "strength": 0.5 } },
                           "normalTexture": { "index": 0, "scale": 2 }, "occlusionTexture": { "index": 0, "strength": 0.5 } } ] }
        """
        let issues = try JSONDecoder().decode(Document.self, from: Data(json.utf8)).validate()
        let paths = Set(issues.filter { $0.severity == .warning }.map(\.path))
        #expect(paths.contains("/materials/0/pbrMetallicRoughness/baseColorTexture/scale"))
        #expect(paths.contains("/materials/0/pbrMetallicRoughness/baseColorTexture/strength"))
        #expect(!paths.contains("/materials/0/normalTexture/scale"))
        #expect(!paths.contains("/materials/0/occlusionTexture/strength"))
    }

    // Real sample models must pass data validation without false-positive errors.
    @Test
    func sampleModelsHaveNoDataErrors() throws {
        let models = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".sample-assets/Models")
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: models.path) else {
            return
        }
        var failures: [String] = []
        for name in names.sorted() {
            let directory = models.appendingPathComponent(name).appendingPathComponent("glTF-Binary")
            guard let file = try? FileManager.default.contentsOfDirectory(atPath: directory.path).first(where: { $0.hasSuffix(".glb") }),
                  let container = try? Container(url: directory.appendingPathComponent(file)) else {
                continue
            }
            let errors = try container.validate().filter { $0.severity == .error && $0.path != "/extensionsRequired" }
            if !errors.isEmpty {
                failures.append("\(name): \(errors.prefix(3).map(\.description).joined(separator: "; "))")
            }
        }
        #expect(failures.isEmpty, "\(failures.joined(separator: "\n"))")
    }
}

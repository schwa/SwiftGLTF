import Foundation
import Testing

@testable import SwiftGLTF

// Loads every model from a local checkout of KhronosGroup/glTF-Sample-Assets and
// verifies that parsing and accessor access succeed without throwing or crashing.
//
// The assets are NOT downloaded by the test. Run `just download-sample-assets`
// first (CI does this before testing). If the data is missing, the test fails
// with instructions.

private enum SampleAssets {
    // <repo>/Tests/SwiftGLTFTests/SampleAssetsTests.swift -> <repo>
    static var repoRoot: URL {
        TestSupport.repositoryRoot
    }

    static var modelsDirectory: URL {
        repoRoot.appendingPathComponent(".sample-assets/Models", isDirectory: true)
    }

    static var indexURL: URL {
        modelsDirectory.appendingPathComponent("model-index.json")
    }

    struct ModelEntry: Decodable {
        let name: String
        let variants: [String: String]
    }

    static func modelIndex() throws -> [ModelEntry] {
        let data = try Data(contentsOf: indexURL)
        return try JSONDecoder().decode([ModelEntry].self, from: data)
    }
}

@Suite(.serialized)
struct SampleAssetsTests {
    @Test
    func loadsAllBinaryModels() throws {
        guard FileManager.default.fileExists(atPath: SampleAssets.indexURL.path) else {
            Issue.record("""
                glTF-Sample-Assets not found at \(SampleAssets.modelsDirectory.path).
                Run `just download-sample-assets` first.
                """)
            return
        }

        let models = try SampleAssets.modelIndex()
        var failures: [String] = []

        for model in models {
            // Prefer the self-contained binary variant.
            guard let fileName = model.variants["glTF-Binary"] else {
                continue
            }
            let url = SampleAssets.modelsDirectory
                .appendingPathComponent(model.name)
                .appendingPathComponent("glTF-Binary")
                .appendingPathComponent(fileName)
            guard FileManager.default.fileExists(atPath: url.path) else {
                failures.append("\(model.name): missing file \(url.lastPathComponent)")
                continue
            }

            do {
                let container = try Container(url: url)
                // Exercise accessor data extraction (byteStride handling, bounds checks).
                for accessor in container.document.accessors {
                    _ = try? container.data(for: accessor)
                }
            }
            catch {
                failures.append("\(model.name): \(error)")
            }
        }

        #expect(failures.isEmpty, "Models failed to load:\n\(failures.joined(separator: "\n"))")
    }
}

#if os(macOS)
import Foundation
import SceneKit
import Testing

@testable import SwiftGLTF

struct VertexColorUVTests {
    private func sampleModel(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(".sample-assets/Models/\(path)")
    }

    private func sources(in scene: SCNScene, semantic: SCNGeometrySource.Semantic) -> Int {
        var count = 0
        scene.rootNode.enumerateHierarchy { node, _ in
            if let geometry = node.geometry {
                count += geometry.sources(for: semantic).count
            }
        }
        return count
    }

    @Test
    func vertexColorsProduceAColorSource() throws {
        let url = sampleModel("BoxVertexColors/glTF-Embedded/BoxVertexColors.gltf")
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        let scene = try SceneKitGenerator(container: try Container(url: url)).generateSCNScene()
        #expect(sources(in: scene, semantic: .color) >= 1)
    }

    @Test
    func secondUVSetProducesTwoTexcoordSources() throws {
        let url = sampleModel("MultiUVTest/glTF-Binary/MultiUVTest.glb")
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        let scene = try SceneKitGenerator(container: try Container(url: url)).generateSCNScene()
        #expect(sources(in: scene, semantic: .texcoord) >= 2)
    }
}
#endif

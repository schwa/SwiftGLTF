#if os(macOS)
import Foundation
import RealityKit
import SceneKit
import Testing

@testable import SwiftGLTF

struct CameraTests {
    private var camerasURL: URL {
        TestSupport.sampleModels.appendingPathComponent("Cameras/glTF-Embedded/Cameras.gltf")
    }

    @Test
    func sceneKitAppliesNodeCameras() throws {
        guard FileManager.default.fileExists(atPath: camerasURL.path) else {
            return // run `just download-sample-assets`
        }
        let container = try Container(url: camerasURL)
        let scene = try SceneKitGenerator(container: container).generateSCNScene()

        var cameras: [SCNCamera] = []
        scene.rootNode.enumerateHierarchy { node, _ in
            if let camera = node.camera {
                cameras.append(camera)
            }
        }
        #expect(cameras.count == 2)
        #expect(cameras.contains { !$0.usesOrthographicProjection }) // perspective
        #expect(cameras.contains { $0.usesOrthographicProjection })  // orthographic
    }

    @Test @MainActor
    func realityKitAppliesPerspectiveCamera() throws {
        guard FileManager.default.fileExists(atPath: camerasURL.path) else {
            return
        }
        let container = try Container(url: camerasURL)
        let root = try RealityKitGLTFGenerator(container: container).generateRootEntity()

        var found = false
        func walk(_ entity: Entity) {
            if entity.components[PerspectiveCameraComponent.self] != nil {
                found = true
            }
            entity.children.forEach(walk)
        }
        walk(root)
        #expect(found)
    }
}
#endif

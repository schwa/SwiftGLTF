@testable import SwiftGLTF

import XCTest

final class GLTFTests: XCTestCase {
    func testExample() throws {
        let url = Bundle.module.url(forResource: "Box", withExtension: "gltf")!
        let container = try Container(url: url)
        dump(container)
    }

    func testByteStride() throws {
        let url = Bundle.module.url(forResource: "Box-byteStride", withExtension: "glb")!
        let container = try Container(url: url)
        //dump(container)

        let scene = container.document.scenes.first!
        let node = scene.nodes.first!

        //container.data(for: URI)

        dump(node)
    }
}

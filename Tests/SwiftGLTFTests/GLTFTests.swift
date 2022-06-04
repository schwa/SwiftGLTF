@testable import SwiftGLTF

import XCTest

final class GLTFTests: XCTestCase {
    func testExample() throws {
        let url = Bundle.module.url(forResource: "Box", withExtension: "gltf")!
        let data = try Data(contentsOf: url)
        let document = try JSONDecoder().decode(Document.self, from: data)
        dump(document)
    }
}

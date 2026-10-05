import Foundation
import Testing

@testable import SwiftGLTF

struct AttributeSemanticTests {
    // Spec-valid attribute names outside the common set must not crash.
    @Test
    func unknownAttributeNamesDecode() throws {
        let json = """
        {
          "asset": { "version": "2.0" },
          "meshes": [ {
            "primitives": [ {
              "attributes": { "POSITION": 0, "TEXCOORD_3": 1, "COLOR_1": 2, "_CUSTOM": 3 }
            } ]
          } ]
        }
        """
        let document = try JSONDecoder().decode(Document.self, from: Data(json.utf8))
        let attributes = document.meshes[0].primitives[0].attributes
        #expect(attributes[.POSITION]?.index == 0)
        #expect(attributes[Mesh.Primitive.Semantic(rawValue: "TEXCOORD_3")]?.index == 1)
        #expect(attributes["COLOR_1"]?.index == 2)
        #expect(attributes["_CUSTOM"]?.index == 3)
    }
}

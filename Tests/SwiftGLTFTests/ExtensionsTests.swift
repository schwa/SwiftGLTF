import Foundation
import Testing

@testable import SwiftGLTF

private struct KHRMaterialsUnlit: GLTFExtension {
    static let extensionName = "KHR_materials_unlit"
}

private struct KHRMaterialsEmissiveStrength: GLTFExtension {
    static let extensionName = "KHR_materials_emissive_strength"
    let emissiveStrength: Float
}

struct ExtensionsTests {
    // A minimal glTF document with a material carrying two extensions and extras.
    private let json = """
    {
      "asset": { "version": "2.0" },
      "materials": [
        {
          "name": "M",
          "extensions": {
            "KHR_materials_unlit": {},
            "KHR_materials_emissive_strength": { "emissiveStrength": 3.5 },
            "VENDOR_unknown_ext": { "foo": [1, 2, 3], "bar": "baz" }
          },
          "extras": { "note": "hello", "count": 7 }
        }
      ]
    }
    """

    private func document() throws -> Document {
        try JSONDecoder().decode(Document.self, from: Data(json.utf8))
    }

    @Test
    func registeredExtensionDecodes() throws {
        let material = try document().materials[0]
        let unlit = try material.extensionValue(KHRMaterialsUnlit.self)
        #expect(unlit != nil)

        let emissive = try material.extensionValue(KHRMaterialsEmissiveStrength.self)
        #expect(emissive?.emissiveStrength == 3.5)
    }

    @Test
    func unknownExtensionIsPreservedAsRawJSON() throws {
        let material = try document().materials[0]
        let raw = material.extensions?["VENDOR_unknown_ext"]
        guard case let .object(fields)? = raw else {
            Issue.record("unknown extension not preserved as object")
            return
        }
        #expect(fields["bar"] == .string("baz"))
        #expect(fields["foo"] == .array([.number(1), .number(2), .number(3)]))
    }

    @Test
    func extrasAccessible() throws {
        let material = try document().materials[0]
        guard case let .object(extras)? = material.extras else {
            Issue.record("extras not decoded as object")
            return
        }
        #expect(extras["note"] == .string("hello"))
        #expect(extras["count"] == .number(7))
    }

    @Test
    func absentExtensionsAreNil() throws {
        let json = #"{ "asset": { "version": "2.0" }, "materials": [ { "name": "plain" } ] }"#
        let document = try JSONDecoder().decode(Document.self, from: Data(json.utf8))
        let material = document.materials[0]
        #expect(material.extensions == nil)
        #expect(material.extras == nil)
        #expect(try material.extensionValue(KHRMaterialsUnlit.self) == nil)
    }
}

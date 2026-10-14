import Foundation
import SwiftGLTF
import Testing

struct RemovingExtensionsTests {
    static let json = """
    {
      "asset": {"version": "2.0", "extensions": {"A": {}}},
      "extensionsUsed": ["A", "B"],
      "extensionsRequired": ["A"],
      "extensions": {"A": {"x": 1}, "B": {"y": 2}},
      "accessors": [{"componentType": 5126, "count": 1, "type": "SCALAR", "extensions": {"A": {}},
        "sparse": {"count": 1, "extensions": {"A": {}},
          "indices": {"bufferView": 0, "componentType": 5125, "extensions": {"A": {}}},
          "values": {"bufferView": 0, "extensions": {"A": {}}}}}],
      "buffers": [{"byteLength": 4, "extensions": {"A": {}}}],
      "bufferViews": [{"buffer": 0, "byteLength": 4, "extensions": {"A": {}}}],
      "cameras": [{"type": "perspective", "perspective": {"yfov": 1, "znear": 0.1, "extensions": {"A": {}}}, "extensions": {"A": {}, "B": {}}}],
      "materials": [{"extensions": {"A": {}},
        "pbrMetallicRoughness": {"extensions": {"A": {}}, "baseColorTexture": {"index": 0, "extensions": {"A": {}}}},
        "normalTexture": {"index": 0, "extensions": {"A": {}}},
        "emissiveTexture": {"index": 0, "extensions": {"A": {}}}}],
      "meshes": [{"primitives": [{"attributes": {"POSITION": 0}, "extensions": {"A": {}}}], "extensions": {"A": {}}}],
      "nodes": [{"extensions": {"A": {}}}],
      "samplers": [{"extensions": {"A": {}}}],
      "scenes": [{"nodes": [0], "extensions": {"A": {}}}],
      "textures": [{"source": 0, "extensions": {"A": {}}}],
      "images": [{"uri": "a.png", "extensions": {"A": {}}}],
      "animations": [{"extensions": {"A": {}},
        "channels": [{"sampler": 0, "target": {"node": 0, "path": "translation", "extensions": {"A": {}}}, "extensions": {"A": {}}}],
        "samplers": [{"input": 0, "output": 0, "extensions": {"A": {}}}]}],
      "skins": [{"joints": [0], "extensions": {"A": {}}}]
    }
    """

    static func stripped(_ value: Any, names: Set<String>) -> Any {
        if var object = value as? [String: Any] {
            for (key, child) in object {
                object[key] = stripped(child, names: names)
            }
            if var extensions = object["extensions"] as? [String: Any] {
                for name in names {
                    extensions[name] = nil
                }
                object["extensions"] = extensions.isEmpty ? nil : extensions
            }
            for key in ["extensionsUsed", "extensionsRequired"] {
                if let list = object[key] as? [String] {
                    object[key] = list.filter { !names.contains($0) }
                }
            }
            return object
        }
        if let array = value as? [Any] {
            return array.map { stripped($0, names: names) }
        }
        return value
    }

    @Test
    func matchesJSONStrippingOracle() throws {
        let data = Data(Self.json.utf8)
        let document = try JSONDecoder().decode(Document.self, from: data)
        let oracleData = try JSONSerialization.data(withJSONObject: Self.stripped(JSONSerialization.jsonObject(with: data), names: ["A"]))
        let expected = try JSONDecoder().decode(Document.self, from: oracleData)

        let result = document.removingExtensions(["A"])
        #expect(result == expected)
        #expect(result.extensionsUsed == ["B"])
        #expect(result.extensionsRequired.isEmpty)
        #expect(result.extensions?["B"] != nil)
        #expect(result.cameras[0].extensions?.values.keys.sorted() == ["B"])
        #expect(result.nodes[0].extensions == nil)
        #expect(result.materials[0].pbrMetallicRoughness?.baseColorTexture?.extensions == nil)
        #expect(result.animations[0].channels[0].target.extensions == nil)
    }

    @Test
    func emptySetIsIdentity() throws {
        let document = try JSONDecoder().decode(Document.self, from: Data(Self.json.utf8))
        #expect(document.removingExtensions([]) == document)
    }
}

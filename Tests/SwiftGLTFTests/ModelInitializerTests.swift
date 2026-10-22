import Foundation
import SwiftGLTF
import Testing

// Non-testable import: consumers can build every model type in code (#69).
struct ModelInitializerTests {
    // Built in code, each value must equal decoding the same JSON (defaults included).
    func expectMatches<T: Decodable & Equatable>(_ value: T, _ json: String) throws {
        #expect(value == (try JSONDecoder().decode(T.self, from: Data(json.utf8))))
    }

    @Test func initializersMatchDecoding() throws {
        try expectMatches(Asset(), #"{"version": "2.0"}"#)
        try expectMatches(Buffer(byteLength: 4, uri: URI("a.bin")), #"{"byteLength": 4, "uri": "a.bin"}"#)
        try expectMatches(BufferView(buffer: Index(0), byteLength: 4), #"{"buffer": 0, "byteLength": 4}"#)
        try expectMatches(
            Accessor(bufferView: Index(0), componentType: .FLOAT, count: 1, type: .VEC3, max: [1, 1, 1], min: [0, 0, 0]),
            #"{"bufferView": 0, "componentType": 5126, "count": 1, "type": "VEC3", "max": [1, 1, 1], "min": [0, 0, 0]}"#
        )
        try expectMatches(Mesh(primitives: [.init(attributes: [.POSITION: Index(0)], material: Index(0))]), #"{"primitives": [{"attributes": {"POSITION": 0}, "material": 0}]}"#)
        try expectMatches(Material(pbrMetallicRoughness: .init(baseColorFactor: [1, 0, 0, 1])), #"{"pbrMetallicRoughness": {"baseColorFactor": [1, 0, 0, 1]}}"#)
        try expectMatches(Texture(source: Index(0)), #"{"source": 0}"#)
        try expectMatches(TextureInfo(index: Index(0)), #"{"index": 0}"#)
        try expectMatches(Image(uri: URI("a.png")), #"{"uri": "a.png"}"#)
        try expectMatches(Scene(nodes: [Index(0)]), #"{"nodes": [0]}"#)
        try expectMatches(Skin(joints: [Index(0)]), #"{"joints": [0]}"#)
        try expectMatches(
            Animation(channels: [.init(sampler: 0, target: .init(node: Index(0), path: .rotation))], samplers: [.init(input: Index(0), output: Index(1))]),
            #"{"channels": [{"sampler": 0, "target": {"node": 0, "path": "rotation"}}], "samplers": [{"input": 0, "output": 1}]}"#
        )
    }

    // Node decoding fills in an identity matrix, so compare the encoded form.
    @Test func nodeEncodesItsFields() throws {
        let node = Node(name: "n", children: [Index(1)], mesh: Index(0), translation: [1, 2, 3])
        let decoded = try JSONDecoder().decode(Node.self, from: JSONEncoder().encode(node))
        #expect(decoded.name == "n")
        #expect(decoded.children == [Index(1)])
        #expect(decoded.mesh == Index(0))
        #expect(decoded.translation == [1, 2, 3])
    }

    @Test func documentRoundTrips() throws {
        let document = Document(scene: Index(0), scenes: [Scene(nodes: [Index(0)])], nodes: [Node(name: "root")])
        let decoded = try JSONDecoder().decode(Document.self, from: document.jsonData())
        #expect(decoded.scene == Index(0))
        #expect(decoded.scenes == document.scenes)
        #expect(decoded.nodes.map(\.name) == ["root"])
    }
}

import Foundation
import Testing

@testable import SwiftGLTF

// A container with a replaced document keeps reading the original file's buffers.
@Test func withDocumentKeepsTheBuffers() throws {
    let buffer = TestSupport.bytes([Float](arrayLiteral: 1, 2, 3))
    let json = """
    {
      "asset": {"version": "2.0"},
      "buffers": [{"byteLength": 12, "uri": "\(TestSupport.dataURI(buffer))"}],
      "bufferViews": [{"buffer": 0, "byteLength": 12}],
      "accessors": [{"bufferView": 0, "componentType": 5126, "count": 1, "type": "VEC3"}],
      "extensionsUsed": ["TEST_a"]
    }
    """
    let container = try TestSupport.container(json: json)
    let document = try JSONDecoder().decode(Document.self, from: Data(json.replacingOccurrences(of: #""extensionsUsed": ["TEST_a"]"#, with: #""extensionsUsed": []"#).utf8))
    let replaced = container.withDocument(document)
    #expect(replaced.document.extensionsUsed.isEmpty)
    #expect([Float](withUnsafeData: try replaced.data(for: replaced.document.accessors[0])) == [1, 2, 3])
}

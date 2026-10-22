import Foundation
import SwiftGLTF
import Testing

// Absent optional properties must be omitted, not written as null; glTF-Validator
// rejects `"name": null` (CI TYPE_MISMATCH on samplers).
@Test func absentPropertiesAreNotWrittenAsNull() throws {
    let json = """
    {"asset": {"version": "2.0"}, "samplers": [{}], "nodes": [{}], "materials": [{}], "textures": [{}],
     "images": [{"uri": "a.png"}], "cameras": [{"type": "perspective", "perspective": {"yfov": 1, "znear": 0.1}}]}
    """
    let document = try JSONDecoder().decode(Document.self, from: Data(json.utf8))
    let encoded = String(decoding: try document.jsonData(), as: UTF8.self)
    #expect(!encoded.contains("null"), "\(encoded)")
}

import Foundation
import SwiftGLTF
import Testing

// Non-testable import: consumers must be able to edit a document (#70).
@Test func consumersCanMutateDocument() throws {
    let json = #"{"asset": {"version": "2.0"}, "scenes": [{"nodes": []}], "extras": {"a": 1}}"#
    var document = try JSONDecoder().decode(Document.self, from: Data(json.utf8))
    let other = document
    document.extensionsUsed.append("KHR_materials_unlit")
    document.scenes.append(document.scenes[0])
    document.scene = other.scene
    document.extras = nil
    #expect(document.extensionsUsed == ["KHR_materials_unlit"])
    #expect(document.scenes.count == 2)
    #expect(document.extras == nil)
}

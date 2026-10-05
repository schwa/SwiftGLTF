import CoreGraphics
import Foundation
import Testing

@testable import SwiftGLTF

// Errors must say what went wrong, not just GLTFError.unknown (#52).
struct ErrorMessageTests {
    private func message(_ body: () throws -> Void) -> String? {
        do {
            try body()
            return nil
        }
        catch let error as GLTFError {
            switch error {
            case .malformedGLB(let message), .unsupported(let message), .missingResource(let message), .invalidDocument(let message):
                return message
            default:
                return "\(error)"
            }
        }
        catch {
            return nil
        }
    }

    @Test
    func unparseableURINamesTheURI() throws {
        let container = try TestSupport.container(json: #"""
        { "asset": { "version": "2.0" }, "buffers": [ { "byteLength": 4, "uri": "http://[bad" } ] }
        """#)
        let text = message { _ = try container.data(for: container.document.buffers[0]) }
        #expect(text?.contains("http://[bad") == true, "\(text ?? "no error")")
    }

    @Test
    func urilessBufferOutsideGLBIsExplained() throws {
        let container = try TestSupport.container(json: #"{ "asset": { "version": "2.0" }, "buffers": [ { "byteLength": 4 } ] }"#)
        let text = message { _ = try container.data(for: container.document.buffers[0]) }
        #expect(text?.contains("uri") == true, "\(text ?? "no error")")
    }

    @Test
    func unsupportedFileExtensionNamesTheExtension() throws {
        let url = try TestSupport.temporaryDirectory().appendingPathComponent("model.obj")
        try Data("{}".utf8).write(to: url)
        let text = message { _ = try Container(url: url) }
        #expect(text?.contains("obj") == true, "\(text ?? "no error")")
    }

    @Test
    func wrongSizedMatrixGivesTheCount() {
        let json = #"{ "asset": { "version": "2.0" }, "nodes": [ { "matrix": [1, 0, 0] } ] }"#
        let text = message { _ = try JSONDecoder().decode(Document.self, from: Data(json.utf8)) }
        #expect(text?.contains("3") == true, "\(text ?? "no error")")
    }

    @Test
    func undecodableImageIsExplained() {
        let text = message { _ = try CGImage.load(data: Data([1, 2, 3])) }
        #expect(text?.contains("decode") == true, "\(text ?? "no error")")
    }
}

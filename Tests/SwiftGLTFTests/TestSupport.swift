import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

@testable import SwiftGLTF

enum TestSupport {
    static func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("swiftgltf-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // Writes `json` as a .gltf (in `directory`, or a fresh temp directory) and loads it.
    static func container(json: String, in directory: URL? = nil, name: String = "model.gltf") throws -> Container {
        let url = try (directory ?? temporaryDirectory()).appendingPathComponent(name)
        try Data(json.utf8).write(to: url)
        return try Container(url: url)
    }

    static func dataURI(_ data: Data, mimeType: String = "application/octet-stream") -> String {
        "data:\(mimeType);base64,\(data.base64EncodedString())"
    }

    static func bytes<T>(_ values: [T]) -> Data {
        values.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    // A 1x1 opaque PNG of the given color.
    static func png(red: CGFloat = 1, green: CGFloat = 1, blue: CGFloat = 1) -> Data {
        let context = CGContext(
            data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: red, green: green, blue: blue, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        CGImageDestinationFinalize(destination)
        return data as Data
    }

    static var sampleModels: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".sample-assets/Models")
    }
}

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

    // A 1x1 RGBA8 bitmap context in `space` (device RGB by default).
    static func pixelContext(data: UnsafeMutableRawPointer? = nil, space: CGColorSpace = CGColorSpaceCreateDeviceRGB()) -> CGContext {
        CGContext(
            data: data,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
    }

    // A 1x1 opaque image of the given color.
    static func image(red: CGFloat = 1, green: CGFloat = 1, blue: CGFloat = 1) -> CGImage {
        let context = pixelContext()
        context.setFillColor(CGColor(red: red, green: green, blue: blue, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        return context.makeImage()!
    }

    // A 1x1 opaque PNG of the given color.
    static func png(red: CGFloat = 1, green: CGFloat = 1, blue: CGFloat = 1) -> Data {
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image(red: red, green: green, blue: blue), nil)
        CGImageDestinationFinalize(destination)
        return data as Data
    }

    // RGBA of the top-left pixel of `image`, drawn into `space`.
    static func firstPixel(of image: CGImage, space: CGColorSpace = CGColorSpaceCreateDeviceRGB()) -> [UInt8] {
        var pixel = [UInt8](repeating: 0, count: 4)
        pixel.withUnsafeMutableBytes { buffer in
            let context = pixelContext(data: buffer.baseAddress, space: space)
            let corner = image.cropping(to: CGRect(x: 0, y: 0, width: 1, height: 1)) ?? image
            context.draw(corner, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        return pixel
    }

    static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    static var sampleModels: URL {
        repositoryRoot.appendingPathComponent(".sample-assets/Models")
    }
}

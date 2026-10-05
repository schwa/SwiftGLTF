import CoreGraphics
import Testing

@testable import SwiftGLTF

// Channel extraction turns one channel into an opaque gray image with the exact
// stored values (glTF's packed metallic/roughness/occlusion are data) (#54).
struct ChannelExtractionTests {
    // Raw bytes, so the expected values are the actual stored pixel values.
    private let source = TestSupport.image(rgba: [200, 100, 50, 255])

    @Test(arguments: [(ImageChannel.red, 200), (.green, 100), (.blue, 50)])
    func extractsChannelAsGray(channel: ImageChannel, expected: Int) throws {
        let pixel = TestSupport.firstPixel(of: try source.extracting(channel))
        for component in 0 ..< 3 {
            #expect(abs(Int(pixel[component]) - expected) <= 1, "component \(component) = \(pixel[component]), expected \(expected)")
        }
        #expect(pixel[3] == 255) // stays opaque
    }
}

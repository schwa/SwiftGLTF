#if os(macOS)
import SceneKit
import Testing

@testable import SwiftGLTF

struct SamplerMappingTests {
    // glTF CLAMP_TO_EDGE is SceneKit .clamp, not .clampToBorder (#47).
    @Test
    func wrapModesMapToSceneKit() {
        #expect(SCNWrapMode(.CLAMP_TO_EDGE) == .clamp)
        #expect(SCNWrapMode(.MIRRORED_REPEAT) == .mirror)
        #expect(SCNWrapMode(.REPEAT) == .repeat)
    }

    @Test
    func filterModesMapToSceneKit() {
        #expect(SCNFilterMode(filter: Sampler.MagFilter.NEAREST) == .nearest)
        #expect(SCNFilterMode(filter: Sampler.MagFilter.LINEAR) == .linear)
        #expect(SCNFilterMode(filter: Sampler.MinFilter.NEAREST) == .nearest)
        #expect(SCNFilterMode(filter: Sampler.MinFilter.LINEAR) == .linear)
        // Mipmap min filters have no direct SceneKit equivalent; they fall back to linear.
        #expect(SCNFilterMode(filter: Sampler.MinFilter.LINEAR_MIPMAP_LINEAR) == .linear)
    }
}
#endif

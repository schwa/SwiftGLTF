import Foundation
import simd
import Testing

@testable import SwiftGLTF

struct AnimationTests {
    // Builds a temp .gltf with one buffer holding `times` then `values`, and one
    // animation channel targeting node 0 at `path`.
    private func container(times: [Float], values: [Float], type: String, path: String, interpolation: String) throws -> Container {
        let bytes = (times + values).withUnsafeBufferPointer { Data(buffer: $0) }
        let timesLength = times.count * 4
        let componentCount = ["SCALAR": 1, "VEC3": 3, "VEC4": 4][type]!
        let json = """
        {
          "asset": { "version": "2.0" },
          "buffers": [ { "byteLength": \(bytes.count), "uri": "data:application/octet-stream;base64,\(bytes.base64EncodedString())" } ],
          "bufferViews": [
            { "buffer": 0, "byteOffset": 0, "byteLength": \(timesLength) },
            { "buffer": 0, "byteOffset": \(timesLength), "byteLength": \(values.count * 4) }
          ],
          "accessors": [
            { "bufferView": 0, "componentType": 5126, "count": \(times.count), "type": "SCALAR" },
            { "bufferView": 1, "componentType": 5126, "count": \(values.count / componentCount), "type": "\(type)" }
          ],
          "nodes": [ {} ],
          "animations": [ {
            "channels": [ { "sampler": 0, "target": { "node": 0, "path": "\(path)" } } ],
            "samplers": [ { "input": 0, "output": 1, "interpolation": "\(interpolation)" } ]
          } ]
        }
        """
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("anim-\(UUID().uuidString).gltf")
        try Data(json.utf8).write(to: url)
        return try Container(url: url)
    }

    private func sample(_ container: Container, at time: Float) throws -> [Float] {
        let animation = container.document.animations[0]
        return try container.sample(animation.channels[0], of: animation, at: time)
    }

    @Test
    func decodesChannelsAndSamplers() throws {
        let container = try container(times: [0, 1], values: [0, 0, 0, 2, 4, 6], type: "VEC3", path: "translation", interpolation: "LINEAR")
        let animation = container.document.animations[0]
        #expect(animation.channels.count == 1)
        #expect(animation.channels[0].target.path == .translation)
        #expect(animation.channels[0].target.node?.index == 0)
        #expect(animation.samplers[0].interpolation == .LINEAR)
    }

    @Test
    func linearInterpolatesAndClamps() throws {
        let container = try container(times: [0, 1], values: [0, 0, 0, 2, 4, 6], type: "VEC3", path: "translation", interpolation: "LINEAR")
        #expect(try sample(container, at: 0.5) == [1, 2, 3])
        #expect(try sample(container, at: -1) == [0, 0, 0])
        #expect(try sample(container, at: 5) == [2, 4, 6])
    }

    @Test
    func stepHoldsPreviousValue() throws {
        let container = try container(times: [0, 1], values: [0, 0, 0, 2, 4, 6], type: "VEC3", path: "translation", interpolation: "STEP")
        #expect(try sample(container, at: 0.99) == [0, 0, 0])
    }

    @Test
    func rotationUsesSlerp() throws {
        let end = simd_quatf(angle: .pi / 2, axis: [1, 0, 0]).vector
        let container = try container(times: [0, 1], values: [0, 0, 0, 1, end.x, end.y, end.z, end.w], type: "VEC4", path: "rotation", interpolation: "LINEAR")
        let result = try sample(container, at: 0.5)
        let expected = simd_quatf(angle: .pi / 4, axis: [1, 0, 0]).vector
        #expect(abs(simd_dot(SIMD4(result[0], result[1], result[2], result[3]), expected)) > 0.9999)
    }

    @Test
    func cubicSplineHitsKeyframesAndInterpolates() throws {
        // Scalar weights with zero tangents: [in, value, out] per keyframe.
        let container = try container(times: [0, 1], values: [0, 0, 0, 0, 2, 0], type: "SCALAR", path: "weights", interpolation: "CUBICSPLINE")
        #expect(try sample(container, at: 0) == [0])
        #expect(try sample(container, at: 1) == [2])
        #expect(abs(try sample(container, at: 0.5)[0] - 1) < 1e-5) // symmetric Hermite
    }

    @Test
    func decodesRealAnimatedSample() throws {
        let url = TestSupport.sampleModels.appendingPathComponent("BoxAnimated/glTF-Binary/BoxAnimated.glb")
        guard FileManager.default.fileExists(atPath: url.path) else {
            return // run `just download-sample-assets`
        }
        let container = try Container(url: url)
        let animation = try #require(container.document.animations.first)
        #expect(!animation.channels.isEmpty)
        for channel in animation.channels {
            let keyframes = try container.keyframes(for: animation.samplers[channel.sampler])
            #expect(keyframes.duration > 0)
            let value = try container.sample(channel, of: animation, at: keyframes.duration / 2)
            #expect(value.count == keyframes.componentsPerValue)
        }
    }
}

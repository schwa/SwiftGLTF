import Foundation
import simd

// glTF animation data. Renderer-agnostic: generators turn this into
// SCNAnimation / RealityKit animations separately.
public struct Animation: Codable, Hashable, Sendable, Resolver, Extensible {
    public static let documentKeyPath = \Document.animations

    public struct Channel: Codable, Hashable, Sendable {
        public struct Target: Codable, Hashable, Sendable {
            // Absent when the target is supplied by an extension (e.g. KHR_animation_pointer).
            public let node: Index<Node>?
            public let path: Path
            public let extensions: Extensions?
        }

        // Index into the owning animation's `samplers`.
        public let sampler: Int
        public let target: Target
        public let extensions: Extensions?
    }

    // Open set so extension paths (e.g. "pointer") don't fail decoding.
    public struct Path: RawRepresentable, Hashable, Sendable, Codable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public init(from decoder: Decoder) throws {
            rawValue = try decoder.singleValueContainer().decode(String.self)
        }

        public static let translation = Self(rawValue: "translation")
        public static let rotation = Self(rawValue: "rotation")
        public static let scale = Self(rawValue: "scale")
        public static let weights = Self(rawValue: "weights")
    }

    public enum Interpolation: String, Codable, Hashable, Sendable {
        case LINEAR
        case STEP
        case CUBICSPLINE
    }

    public struct Sampler: Codable, Hashable, Sendable {
        public let input: Index<Accessor> // keyframe times (seconds)
        public let output: Index<Accessor> // keyframe values
        public let interpolation: Interpolation
        public let extensions: Extensions?

        public enum CodingKeys: CodingKey {
            case input
            case output
            case interpolation
            case extensions
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            input = try container.decode(Index<Accessor>.self, forKey: .input)
            output = try container.decode(Index<Accessor>.self, forKey: .output)
            interpolation = try container.decodeIfPresent(Interpolation.self, forKey: .interpolation) ?? .LINEAR
            extensions = try container.decodeIfPresent(Extensions.self, forKey: .extensions)
        }
    }

    public let channels: [Channel]
    public let samplers: [Sampler]
    public let name: String?
    public let extensions: Extensions?
    public let extras: JSONValue?
}

// Decoded keyframes for one sampler: times plus a flat array of output values.
public struct AnimationKeyframes: Sendable {
    public let times: [Float]
    public let values: [Float]
    // Number of floats per keyframe value (3 translation/scale, 4 rotation, N weights).
    public let componentsPerValue: Int
    public let interpolation: Animation.Interpolation

    public var duration: Float {
        times.last ?? 0
    }

    // Samples the curve at `time` (clamped to the keyframe range).
    // `isRotation` enables quaternion slerp + normalisation.
    public func sample(at time: Float, isRotation: Bool = false) -> [Float] {
        let count = times.count
        guard count > 0 else {
            return []
        }
        let stride = interpolation == .CUBICSPLINE ? componentsPerValue * 3 : componentsPerValue
        // For CUBICSPLINE each keyframe stores [inTangent, value, outTangent].
        func value(_ keyframe: Int) -> [Float] {
            let base = keyframe * stride + (interpolation == .CUBICSPLINE ? componentsPerValue : 0)
            return Array(values[base ..< base + componentsPerValue])
        }
        if time <= times[0] || count == 1 {
            return value(0)
        }
        if time >= times[count - 1] {
            return value(count - 1)
        }
        let upper = times.firstIndex { $0 > time } ?? (count - 1)
        let lower = upper - 1
        let delta = times[upper] - times[lower]
        let t = delta > 0 ? (time - times[lower]) / delta : 0

        switch interpolation {
        case .STEP:
            return value(lower)
        case .LINEAR:
            let a = value(lower)
            let b = value(upper)
            if isRotation, componentsPerValue == 4 {
                let qa = simd_quatf(vector: SIMD4(a[0], a[1], a[2], a[3]))
                let qb = simd_quatf(vector: SIMD4(b[0], b[1], b[2], b[3]))
                let q = simd_slerp(qa, qb, t).normalized.vector
                return [q.x, q.y, q.z, q.w]
            }
            return zip(a, b).map { $0 + ($1 - $0) * t }
        case .CUBICSPLINE:
            // Hermite spline per the glTF spec; tangents are scaled by delta.
            let p0 = value(lower)
            let p1 = value(upper)
            let m0Base = lower * stride + 2 * componentsPerValue // outTangent of lower
            let m1Base = upper * stride // inTangent of upper
            let t2 = t * t
            let t3 = t2 * t
            var result = [Float](repeating: 0, count: componentsPerValue)
            for index in 0 ..< componentsPerValue {
                let m0 = values[m0Base + index] * delta
                let m1 = values[m1Base + index] * delta
                result[index] = (2 * t3 - 3 * t2 + 1) * p0[index]
                    + (t3 - 2 * t2 + t) * m0
                    + (-2 * t3 + 3 * t2) * p1[index]
                    + (t3 - t2) * m1
            }
            if isRotation, componentsPerValue == 4 {
                let q = simd_quatf(vector: SIMD4(result[0], result[1], result[2], result[3])).normalized.vector
                return [q.x, q.y, q.z, q.w]
            }
            return result
        }
    }
}

public extension Container {
    func keyframes(for sampler: Animation.Sampler) throws -> AnimationKeyframes {
        let inputAccessor = try sampler.input.resolve(in: document)
        let outputAccessor = try sampler.output.resolve(in: document)
        let times = try floatComponents(for: inputAccessor)
        let values = try floatComponents(for: outputAccessor)
        // Elements per keyframe in the output (3 for CUBICSPLINE triples).
        let perKeyframe = sampler.interpolation == .CUBICSPLINE ? 3 : 1
        let keyframeCount = max(times.count, 1)
        let componentsPerValue = values.count / (keyframeCount * perKeyframe)
        return AnimationKeyframes(
            times: times,
            values: values,
            componentsPerValue: componentsPerValue,
            interpolation: sampler.interpolation
        )
    }

    // Samples one channel of an animation at `time`.
    func sample(_ channel: Animation.Channel, of animation: Animation, at time: Float) throws -> [Float] {
        guard animation.samplers.indices.contains(channel.sampler) else {
            throw GLTFError.missingResource("Animation channel references missing sampler \(channel.sampler)")
        }
        let keyframes = try keyframes(for: animation.samplers[channel.sampler])
        return keyframes.sample(at: time, isRotation: channel.target.path == .rotation)
    }
}

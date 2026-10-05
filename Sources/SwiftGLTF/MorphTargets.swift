import Foundation

public extension Node {
    // Effective morph weights for this node: node.weights, else mesh.weights,
    // else zeros (one per target of the mesh's first primitive).
    func morphWeights(in document: Document) throws -> [Float] {
        if let weights {
            return weights
        }
        guard let mesh = try mesh?.resolve(in: document) else {
            return []
        }
        if !mesh.weights.isEmpty {
            return mesh.weights
        }
        return Array(repeating: 0, count: mesh.primitives.first?.targets.count ?? 0)
    }
}

public extension Container {
    // Applies morph targets to a base attribute on the CPU:
    // result = base + sum(weights[i] * target[i]).
    // Reference implementation, renderer-agnostic; renderers may do this on the GPU.
    func morphed(
        _ semantic: Mesh.Primitive.Semantic,
        of primitive: Mesh.Primitive,
        weights: [Float]
    ) throws -> [Float]? {
        guard let baseIndex = primitive.attributes[semantic] else {
            return nil
        }
        var result = try floatComponents(for: baseIndex.resolve(in: document))
        for (targetIndex, target) in primitive.targets.enumerated() {
            guard targetIndex < weights.count, weights[targetIndex] != 0,
                  let deltaIndex = target[semantic] else {
                continue
            }
            let deltas = try floatComponents(for: deltaIndex.resolve(in: document))
            guard deltas.count == result.count else {
                throw GLTFError.invalidDocument("Morph target \(targetIndex) \(semantic.rawValue) count mismatch")
            }
            let weight = weights[targetIndex]
            for component in result.indices {
                result[component] += weight * deltas[component]
            }
        }
        return result
    }
}

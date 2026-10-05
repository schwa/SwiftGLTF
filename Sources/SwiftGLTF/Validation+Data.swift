import Foundation

public extension Container {
    // Structural validation (Document.validate) plus checks that need buffer data:
    // accessor min/max against the actual values, and index values against the
    // primitive's vertex count. Accessors that fail to load are skipped here; the
    // structural pass reports why.
    func validate() throws -> [ValidationIssue] {
        var issues = document.validate()
        // Data checks on a structurally broken document would only cascade.
        if issues.contains(where: { $0.severity == .error }) {
            return issues
        }
        issues += boundsIssues()
        issues += try indexRangeIssues()
        return issues
    }

    private func boundsIssues() -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        for (index, accessor) in document.accessors.enumerated() {
            // Skip normalized accessors: whether min/max are stored normalized or
            // raw is ambiguous, and guessing would produce false positives.
            guard !accessor.normalized, accessor.min != nil || accessor.max != nil,
                  let values = try? floatComponents(for: accessor) else {
                continue
            }
            let components = accessor.type.componentCount
            var actualMin = [Float](repeating: .infinity, count: components)
            var actualMax = [Float](repeating: -.infinity, count: components)
            for (offset, value) in values.enumerated() {
                let component = offset % components
                actualMin[component] = Swift.min(actualMin[component], value)
                actualMax[component] = Swift.max(actualMax[component], value)
            }
            let path = "/accessors/\(index)"
            if let declared = accessor.min {
                issues += compare(declared: declared, actual: actualMin, path: "\(path)/min", isMinimum: true)
            }
            if let declared = accessor.max {
                issues += compare(declared: declared, actual: actualMax, path: "\(path)/max", isMinimum: false)
            }
        }
        return issues
    }

    private func compare(declared: [Float], actual: [Float], path: String, isMinimum: Bool) -> [ValidationIssue] {
        guard declared.count == actual.count else {
            return [ValidationIssue(severity: .error, path: path, message: "has \(declared.count) values, expected \(actual.count)")]
        }
        var issues: [ValidationIssue] = []
        for component in declared.indices {
            let expected = declared[component]
            let found = actual[component]
            let tolerance = Swift.max(abs(expected), 1) * 1e-5
            if abs(expected - found) <= tolerance {
                continue
            }
            // Data outside the declared bounds breaks consumers that trust them.
            let violates = isMinimum ? found < expected : found > expected
            issues.append(ValidationIssue(
                severity: violates ? .error : .warning,
                path: path,
                message: violates
                    ? "component \(component): data value \(found) is outside declared \(isMinimum ? "min" : "max") \(expected)"
                    : "component \(component): declared \(expected) but data \(isMinimum ? "min" : "max") is \(found) (must be exact)"
            ))
        }
        return issues
    }

    private func indexRangeIssues() throws -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        for (meshIndex, mesh) in document.meshes.enumerated() {
            for (primitiveIndex, primitive) in mesh.primitives.enumerated() {
                guard let indicesIndex = primitive.indices,
                      let positionIndex = primitive.attributes[.POSITION],
                      let indices = try? floatComponents(for: indicesIndex.resolve(in: document)) else {
                    continue
                }
                let vertexCount = try positionIndex.resolve(in: document).count
                if let bad = indices.first(where: { Int($0) >= vertexCount }) {
                    issues.append(ValidationIssue(
                        severity: .error,
                        path: "/meshes/\(meshIndex)/primitives/\(primitiveIndex)/indices",
                        message: "index \(Int(bad)) is out of range for \(vertexCount) vertices"
                    ))
                }
            }
        }
        return issues
    }
}

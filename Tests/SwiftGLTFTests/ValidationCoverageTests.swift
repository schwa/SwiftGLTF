import Foundation
import Testing

@testable import SwiftGLTF

// Remaining validator rules, one targeted defect per case.
struct ValidationCoverageTests {
    private func issues(_ json: String) throws -> [ValidationIssue] {
        try JSONDecoder().decode(Document.self, from: Data(json.utf8)).validate()
    }

    private func has(_ issues: [ValidationIssue], _ severity: ValidationIssue.Severity, _ path: String) -> Bool {
        issues.contains { $0.severity == severity && $0.path == path }
    }

    @Test
    func requiredExtensionMustBeListedInUsed() throws {
        let found = try issues(#"{ "asset": { "version": "2.0" }, "extensionsRequired": ["KHR_materials_unlit"] }"#)
        #expect(found.contains { $0.message.contains("not listed in extensionsUsed") })
    }

    @Test
    func invalidByteStride() throws {
        let found = try issues("""
        { "asset": { "version": "2.0" }, "buffers": [ { "byteLength": 16 } ],
          "bufferViews": [ { "buffer": 0, "byteLength": 16, "byteStride": 6 } ] }
        """)
        #expect(has(found, .error, "/bufferViews/0/byteStride"))
    }

    @Test
    func zeroCountAccessor() throws {
        let found = try issues(#"{ "asset": { "version": "2.0" }, "accessors": [ { "componentType": 5126, "count": 0, "type": "SCALAR" } ] }"#)
        #expect(has(found, .error, "/accessors/0/count"))
    }

    @Test
    func sparseProblems() throws {
        let found = try issues("""
        { "asset": { "version": "2.0" },
          "accessors": [ { "componentType": 5126, "count": 1, "type": "SCALAR",
            "sparse": { "count": 2, "indices": { "bufferView": 7, "componentType": 5123 }, "values": { "bufferView": 8 } } } ] }
        """)
        #expect(has(found, .error, "/accessors/0/sparse/count"))
        #expect(has(found, .error, "/accessors/0/sparse/indices/bufferView"))
        #expect(has(found, .error, "/accessors/0/sparse/values/bufferView"))
    }

    @Test
    func primitiveWithoutPositionWarns() throws {
        let found = try issues("""
        { "asset": { "version": "2.0" }, "accessors": [ { "componentType": 5126, "count": 1, "type": "VEC3" } ],
          "meshes": [ { "primitives": [ { "attributes": { "NORMAL": 0 } } ] } ] }
        """)
        #expect(has(found, .warning, "/meshes/0/primitives/0/attributes"))
    }

    @Test
    func morphTargetCountMismatch() throws {
        let found = try issues("""
        { "asset": { "version": "2.0" },
          "accessors": [ { "componentType": 5126, "count": 3, "type": "VEC3" }, { "componentType": 5126, "count": 4, "type": "VEC3" } ],
          "meshes": [ { "primitives": [ { "attributes": { "POSITION": 0 }, "targets": [ { "POSITION": 1 } ] } ] } ] }
        """)
        #expect(has(found, .error, "/meshes/0/primitives/0/targets/0/POSITION"))
    }

    @Test
    func fewerInverseBindMatricesThanJoints() throws {
        let found = try issues("""
        { "asset": { "version": "2.0" }, "nodes": [ {}, {} ],
          "accessors": [ { "componentType": 5126, "count": 1, "type": "MAT4" } ],
          "skins": [ { "joints": [0, 1], "inverseBindMatrices": 0 } ] }
        """)
        #expect(has(found, .error, "/skins/0/inverseBindMatrices"))
    }

    @Test
    func issueDescription() {
        let issue = ValidationIssue(severity: .warning, path: "/nodes/0", message: "example")
        #expect(issue.description == "warning: /nodes/0: example")
    }

    // Node has a hand-written hash (simd_float4x4 is not Hashable).
    @Test
    func nodesHashConsistentlyWithEquality() throws {
        let document = try JSONDecoder().decode(Document.self, from: Data(#"""
        { "asset": { "version": "2.0" },
          "nodes": [ { "matrix": [2,0,0,0, 0,2,0,0, 0,0,2,0, 0,0,0,1] }, { "matrix": [2,0,0,0, 0,2,0,0, 0,0,2,0, 0,0,0,1] }, { "translation": [1, 0, 0] } ] }
        """#.utf8))
        let unique = Set(document.nodes)
        #expect(unique.count == 2)
    }
}

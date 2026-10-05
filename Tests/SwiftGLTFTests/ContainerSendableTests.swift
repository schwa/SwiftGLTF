#if os(macOS)
import Foundation
import RealityKit
import Testing

@testable import SwiftGLTF

// Container must be Sendable: load off the main actor, generate on it (#59).
struct ContainerSendableTests {
    @Test @MainActor
    func loadInBackgroundGenerateOnMainActor() async throws {
        let url = try #require(Bundle.module.url(forResource: "Box", withExtension: "gltf"))
        // Task.detached requires a Sendable result in every language mode.
        let container = try await Task.detached { try Container(url: url) }.value
        let root = try RealityKitGLTFGenerator(container: container).generateRootEntity()
        #expect(!root.children.isEmpty)
    }

    // The data-URI cache is shared by all copies of a Container and must be safe
    // under concurrent access.
    @Test
    func cacheIsSafeUnderConcurrentAccess() async throws {
        let payload = Data((0 ..< 1024).map { UInt8($0 % 251) })
        let container = try TestSupport.container(json: """
        { "asset": { "version": "2.0" },
          "buffers": [ { "byteLength": \(payload.count), "uri": "\(TestSupport.dataURI(payload))" } ] }
        """)
        let buffer = container.document.buffers[0]
        try await withThrowingTaskGroup(of: Data.self) { group in
            for _ in 0 ..< 64 {
                group.addTask { try container.data(for: buffer) }
            }
            for try await data in group {
                #expect(data == payload)
            }
        }
    }
}
#endif

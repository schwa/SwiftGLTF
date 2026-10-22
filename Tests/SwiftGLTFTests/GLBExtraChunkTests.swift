import Foundation
import Testing

@testable import SwiftGLTF

// GLB output keeps chunks other than JSON and BIN (#78).
@Test func glbOutputKeepsExtraChunks() throws {
    func uint32(_ value: Int) -> Data {
        withUnsafeBytes(of: UInt32(value).littleEndian) { Data($0) }
    }
    var json = Data(#"{"asset":{"version":"2.0"},"buffers":[{"byteLength":4}]}"#.utf8)
    while !json.count.isMultiple(of: 4) {
        json.append(0x20)
    }
    let binary = Data([1, 2, 3, 4])
    let extraType = 0x5458_4554 // 'TEXT'
    let extra = Data("hello!!!".utf8)
    var body = uint32(json.count) + uint32(0x4E4F_534A) + json
    body += uint32(binary.count) + uint32(0x004E_4942) + binary
    body += uint32(extra.count) + uint32(extraType) + extra
    let glb = uint32(0x4654_6C67) + uint32(2) + uint32(12 + body.count) + body

    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("glb-chunks-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let source = directory.appendingPathComponent("in.glb")
    try glb.write(to: source)
    let output = directory.appendingPathComponent("out.glb")
    try Container(url: source).write(to: output)

    let chunks = try GLB(url: output).chunks
    let kept = try #require(chunks.first { $0.chunkType.rawValue == UInt32(extraType) })
    #expect(kept.content == extra)
    #expect(Array(chunks.map(\.chunkType.rawValue).prefix(2)) == [0x4E4F_534A, 0x004E_4942])
    #expect(try GLB(url: output).binaryBuffer().prefix(4) == binary)
}

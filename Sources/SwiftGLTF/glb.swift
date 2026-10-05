// import Everything
import Foundation

public struct GLB: Sendable {
    public let header: Header
    public let chunks: [Chunk]
}

public extension GLB {
    init(url: URL) throws {
        let data = try Data(contentsOf: url)
        var scanner = CollectionScanner(elements: data)
        self = try scanner.scanGLB()
    }
}

public extension GLB {
    // The spec requires the JSON chunk to come first.
    func document() throws -> Document {
        guard let chunk = chunks.first, chunk.chunkType == .json else {
            throw GLTFError.malformedGLB("First chunk must be JSON")
        }
        return try JSONDecoder().decode(Document.self, from: chunk.content)
    }

    // The BIN chunk, if any (it need not be the second chunk; unknown chunks are kept).
    func binaryBuffer() throws -> Data {
        guard let chunk = chunks.first(where: { $0.chunkType == .bin }) else {
            throw GLTFError.missingResource("GLB has no BIN chunk")
        }
        return chunk.content
    }
}

public struct Header: Sendable {
    public let magic: UInt32
    public let version: UInt32
    public let length: UInt32
}

public struct Chunk: Sendable {
    public let chunkLength: UInt32
    public let chunkType: ChunkType

    public enum ChunkType: RawRepresentable, Sendable {
        case json
        case bin
        case other(UInt32)

        public init?(rawValue: UInt32) {
            switch rawValue {
            case 0x4E4F_534A:
                self = .json
            case 0x004E_4942:
                self = .bin
            default:
                self = .other(rawValue)
            }
        }

        public var rawValue: UInt32 {
            switch self {
            case .json:
                return 0x4E4F_534A // 'JSON'
            case .bin:
                return 0x004E_4942 // 'BIN'
            case .other(let type):
                return type
            }
        }
    }

    public let content: Data
}

extension CollectionScanner where Element == UInt8 {
    mutating func scanGLB() throws -> GLB {
        let header = try scanHeader()
        guard let body = scan(count: Int(header.length) - 12) else {
            throw GLTFError.malformedGLB("Truncated GLB body")
        }
        var subscanner = CollectionScanner<[UInt8]>(elements: Array(body)) // NOTE: Seem inefficient
        var chunks: [Chunk] = []
        while subscanner.atEnd == false {
            chunks.append(try subscanner.scanChunk())
        }
        return GLB(header: header, chunks: chunks)
    }

    mutating func scanHeader() throws -> Header {
        guard let magic = scan(type: UInt32.self),
              let version = scan(type: UInt32.self),
              let length = scan(type: UInt32.self) else {
            throw GLTFError.malformedGLB("Truncated GLB header")
        }
        return Header(magic: magic, version: version, length: length)
    }

    mutating func scanChunk() throws -> Chunk {
        guard let chunkLength = scan(type: UInt32.self),
              let rawChunkType = scan(type: UInt32.self) else {
            throw GLTFError.malformedGLB("Truncated GLB chunk header")
        }
        guard let content = scan(count: Int(chunkLength)) else {
            throw GLTFError.malformedGLB("Truncated GLB chunk content")
        }
        guard let chunkType = Chunk.ChunkType(rawValue: rawChunkType) else {
            throw GLTFError.malformedGLB("Unknown GLB chunk type \(rawChunkType)")
        }
        return Chunk(chunkLength: chunkLength, chunkType: chunkType, content: Data(content))
    }
}

// extension Chunk {
//    func dump(depth: Int = 0) {
//        let indent = String(repeatElement(" ", count: depth * 2))
//        print("\(indent)\(type)")
//        for child in children {
//            child.dump(depth: depth + 1)
//        }
//    }
// }

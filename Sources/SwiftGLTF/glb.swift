//import Everything
import Foundation

// swiftlint:disable fatal_error_message

public struct GLB {
    public let header: Header
    public let chunks: [Chunk]
}

public extension GLB {
    init(url: URL) throws {
        let data = try Data(contentsOf: url)
        var scanner = CollectionScanner(elements: data)
        self = scanner.scanGLB()!
    }
}

public extension GLB {
    func document() throws -> Document {
        let data = chunks[0].content
        return try JSONDecoder().decode(Document.self, from: data)
    }

    func binaryBuffer() throws -> Data {
        chunks[1].content
    }
}

public struct Header {
    public let magic: UInt32
    public let version: UInt32
    public let length: UInt32
}

public struct Chunk {
    public let chunkLength: UInt32
    public let chunkType: ChunkType

    public enum ChunkType: RawRepresentable {
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
    mutating func scanGLB() -> GLB? {
        guard let header = scanHeader() else {
            fatalError()
        }
        guard let body = scan(count: Int(header.length) - 12) else {
            fatalError()
        }
        var subscanner = CollectionScanner<[UInt8]>(elements: Array(body)) // NOTE: Seem inefficient
        var chunks: [Chunk] = []
        while subscanner.atEnd == false {
            guard let chunk = subscanner.scanChunk() else {
                fatalError()
            }
            chunks.append(chunk)
        }
        return GLB(header: header, chunks: chunks)
    }

    mutating func scanHeader() -> Header? {
        guard let magic = scan(type: UInt32.self) else {
            fatalError()
        }
        guard let version = scan(type: UInt32.self) else {
            fatalError()
        }
        guard let length = scan(type: UInt32.self) else {
            fatalError()
        }
        return Header(magic: magic, version: version, length: length)
    }

    mutating func scanChunk() -> Chunk? {
        guard let chunkLength = scan(type: UInt32.self) else {
            fatalError()
        }
        guard let chunkType = scan(type: UInt32.self) else {
            fatalError()
        }
        guard let content = scan(count: Int(chunkLength)) else {
            fatalError()
        }
        return Chunk(chunkLength: chunkLength, chunkType: .init(rawValue: chunkType)!, content: Data(content))
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

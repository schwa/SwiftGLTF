import Foundation

// A raw JSON value, used to preserve glTF `extensions` and `extras` that the
// library does not model with concrete types.
public enum JSONValue: Hashable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])
}

extension JSONValue: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        }
        else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        }
        else if let number = try? container.decode(Double.self) {
            self = .number(number)
        }
        else if let string = try? container.decode(String.self) {
            self = .string(string)
        }
        else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        }
        else if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
        }
        else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSON value"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let bool):
            try container.encode(bool)
        case .number(let number):
            try container.encode(number)
        case .string(let string):
            try container.encode(string)
        case .array(let array):
            try container.encode(array)
        case .object(let object):
            try container.encode(object)
        }
    }
}

// The `extensions` map of a glTF object: extension name -> raw JSON. Unknown
// extensions are preserved verbatim; known ones can be decoded on demand.
public struct Extensions: Hashable, Sendable {
    public let values: [String: JSONValue]

    public init(_ values: [String: JSONValue]) {
        self.values = values
    }

    public subscript(_ name: String) -> JSONValue? {
        values[name]
    }

    // Decodes a registered extension into its typed representation, or nil if
    // this object does not carry that extension.
    public func value<T: GLTFExtension>(_ type: T.Type) throws -> T? {
        guard let raw = values[T.extensionName] else {
            return nil
        }
        let data = try JSONEncoder().encode(raw)
        return try JSONDecoder().decode(T.self, from: data)
    }
}

extension Extensions: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        values = try container.decode([String: JSONValue].self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(values)
    }
}

// A typed glTF extension. Conformers declare the extension name they decode.
public protocol GLTFExtension: Decodable, Sendable {
    static var extensionName: String { get }
}

// Objects that can carry glTF extensions and extras.
public protocol Extensible {
    var extensions: Extensions? { get }
    var extras: JSONValue? { get }
}

public extension Extensible {
    func extensionValue<T: GLTFExtension>(_ type: T.Type) throws -> T? {
        try extensions?.value(type)
    }
}

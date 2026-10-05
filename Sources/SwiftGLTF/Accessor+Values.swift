import Foundation

public extension Accessor.AttributeType {
    var componentCount: Int {
        switch self {
        case .SCALAR: return 1
        case .VEC2: return 2
        case .VEC3: return 3
        case .VEC4: return 4
        case .MAT2: return 4
        case .MAT3: return 9
        case .MAT4: return 16
        }
    }
}

public extension Container {
    // Reads an accessor's components as Floats, applying the `normalized` flag
    // per the glTF spec. Renderer-agnostic.
    func floatComponents(for accessor: Accessor) throws -> [Float] {
        let data = try data(for: accessor)
        let componentCount = accessor.type.componentCount
        let total = accessor.count * componentCount
        var result = [Float]()
        result.reserveCapacity(total)

        let normalized = accessor.normalized
        data.withUnsafeBytes { raw in
            for index in 0 ..< total {
                let value: Float
                switch accessor.componentType {
                case .FLOAT:
                    value = raw.loadUnaligned(fromByteOffset: index * 4, as: Float.self)
                case .UNSIGNED_BYTE:
                    let raw8 = raw.loadUnaligned(fromByteOffset: index, as: UInt8.self)
                    value = normalized ? Float(raw8) / 255 : Float(raw8)
                case .BYTE:
                    let raw8 = raw.loadUnaligned(fromByteOffset: index, as: Int8.self)
                    value = normalized ? max(Float(raw8) / 127, -1) : Float(raw8)
                case .UNSIGNED_SHORT:
                    let raw16 = raw.loadUnaligned(fromByteOffset: index * 2, as: UInt16.self)
                    value = normalized ? Float(raw16) / 65535 : Float(raw16)
                case .SHORT:
                    let raw16 = raw.loadUnaligned(fromByteOffset: index * 2, as: Int16.self)
                    value = normalized ? max(Float(raw16) / 32767, -1) : Float(raw16)
                case .UNSIGNED_INT:
                    let raw32 = raw.loadUnaligned(fromByteOffset: index * 4, as: UInt32.self)
                    value = Float(raw32)
                }
                result.append(value)
            }
        }
        return result
    }
}

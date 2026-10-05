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
        try accessorReader.floatComponents(for: accessor)
    }
}

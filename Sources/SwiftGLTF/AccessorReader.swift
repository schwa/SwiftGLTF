import Foundation

// Decodes accessor data (byte strides, sparse overrides, component types, the
// normalized flag) from any buffer source. Container and the SceneKit generator
// each supply their own buffer loading.
struct AccessorReader {
    let document: Document
    let bufferData: (Index<Buffer>) throws -> Data

    // Tightly packed element bytes, with sparse overrides applied.
    func data(for accessor: Accessor) throws -> Data {
        let elementSize = accessor.componentType.size * accessor.type.componentCount
        let elementsSize = accessor.count * elementSize

        let subdata: Data
        if let bufferView = try accessor.bufferView?.resolve(in: document) {
            let start = accessor.byteOffset + bufferView.byteOffset
            let data = try bufferData(bufferView.buffer)
            if let byteStride = bufferView.byteStride, byteStride != elementSize {
                // Interleaved buffer view: elements are spaced `byteStride` apart.
                // Copy each element out into a tightly packed result.
                var packed = Data(capacity: elementsSize)
                for index in 0 ..< accessor.count {
                    let elementStart = start + index * byteStride
                    let elementEnd = elementStart + elementSize
                    guard elementEnd <= data.count else {
                        throw GLTFError.accessorOutOfBounds
                    }
                    packed.append(data.subdata(in: elementStart ..< elementEnd))
                }
                subdata = packed
            }
            else {
                guard start + elementsSize <= data.count else {
                    throw GLTFError.accessorOutOfBounds
                }
                subdata = data.subdata(in: start ..< (start + elementsSize))
            }
        }
        else {
            subdata = Data(count: elementsSize) // no bufferView: all zeros
        }

        guard let sparse = accessor.sparse else {
            return subdata
        }
        return try applying(sparse, to: subdata, elementSize: elementSize)
    }

    private func applying(_ sparse: Accessor.Sparse, to base: Data, elementSize: Int) throws -> Data {
        var result = base

        let indexComponentSize: Int
        switch sparse.indices.componentType {
        case .UNSIGNED_BYTE: indexComponentSize = 1
        case .UNSIGNED_SHORT: indexComponentSize = 2
        case .UNSIGNED_INT: indexComponentSize = 4
        default:
            throw GLTFError.unsupported("Unsupported sparse index component type \(sparse.indices.componentType)")
        }

        let indicesBufferView = try sparse.indices.bufferView.resolve(in: document)
        let indicesData = try bufferData(indicesBufferView.buffer)
        let indicesStart = indicesBufferView.byteOffset + sparse.indices.byteOffset

        let valuesBufferView = try sparse.values.bufferView.resolve(in: document)
        let valuesData = try bufferData(valuesBufferView.buffer)
        let valuesStart = valuesBufferView.byteOffset + sparse.values.byteOffset

        for sparseIndex in 0 ..< sparse.count {
            let elementIndex = Int(readLittleEndianUInt(
                indicesData,
                offset: indicesStart + sparseIndex * indexComponentSize,
                size: indexComponentSize
            ))
            let sourceStart = valuesStart + sparseIndex * elementSize
            let destinationStart = elementIndex * elementSize
            guard sourceStart + elementSize <= valuesData.count,
                  destinationStart + elementSize <= result.count else {
                throw GLTFError.accessorOutOfBounds
            }
            result.replaceSubrange(
                destinationStart ..< (destinationStart + elementSize),
                with: valuesData.subdata(in: sourceStart ..< (sourceStart + elementSize))
            )
        }
        return result
    }

    // Components as Float, applying the normalized flag per the glTF spec.
    func floatComponents(for accessor: Accessor) throws -> [Float] {
        let data = try data(for: accessor)
        let total = accessor.count * accessor.type.componentCount
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

private func readLittleEndianUInt(_ data: Data, offset: Int, size: Int) -> UInt32 {
    var value: UInt32 = 0
    for byte in 0 ..< size {
        value |= UInt32(data[data.startIndex + offset + byte]) << (8 * byte)
    }
    return value
}

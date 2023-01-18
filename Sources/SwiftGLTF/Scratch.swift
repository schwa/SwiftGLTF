import CoreGraphics
import CoreImage
import Foundation

extension CGImage {
    @available(*, deprecated, message: "Inefficient")
    private func channel(_ vector: CIVector) -> CGImage {
        let ciImage = CIImage(cgImage: self)
        let filter = CIFilter(name: "CIColorMatrix")!
        filter.setValue(ciImage, forKey: "inputImage")
        filter.setValue(vector, forKey: "inputRVector")
        filter.setValue(vector, forKey: "inputGVector")
        filter.setValue(vector, forKey: "inputBVector")
        filter.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
        filter.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputBiasVector")
        let result = filter.outputImage!
        let context = CIContext()
        let cgImage = context.createCGImage(result, from: result.extent)!
        return cgImage
    }

    var redChannel: CGImage {
        channel(CIVector(x: 1, y: 0, z: 0, w: 0))
    }

    var greenChannel: CGImage {
        channel(CIVector(x: 0, y: 1, z: 0, w: 0))
    }

    var blueChannel: CGImage {
        channel(CIVector(x: 0, y: 0, z: 1, w: 0))
    }
}

extension Index: CustomStringConvertible {
    public var description: String {
        "\(C.Element.self)#\(index)"
    }
}

extension Accessor.ComponentType {
    var size: Int {
        switch self {
        case .FLOAT:
            return 4
        case .UNSIGNED_SHORT:
            return 2
        default:
            // TODO:
            fatalError()
        }
    }
}

extension Accessor.AttributeType {
    var elementCount: Int {
        switch self {
        case .VEC3:
            return 3
        case .SCALAR:
            return 1
        default:
            // TODO:
            fatalError()
        }
    }
}

extension Array {
    init(withUnsafeData data: Data) {
        self = data.withUnsafeBytes { buffer in
            let buffer = buffer.bindMemory(to: Element.self)
            return Array(buffer)
        }
    }
}

extension SIMD where Scalar == Float {
    func within(min: Self, max: Self) -> Bool {
        for n in 0 ..< scalarCount {
            if (min[n] ... max[n]).contains(self[n]) == false {
                return false
            }
        }
        return true
    }
}

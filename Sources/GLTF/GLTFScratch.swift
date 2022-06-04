import CoreGraphics
import CoreImage
import Foundation

extension CGImage {
    // @available(*, deprecated, message: "Inefficient")
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

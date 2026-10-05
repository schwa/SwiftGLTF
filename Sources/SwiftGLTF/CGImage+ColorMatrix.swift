import CoreGraphics
import CoreImage
import Foundation

// Per-pixel texture adjustments shared by the SceneKit and RealityKit generators,
// for glTF factors that a renderer has no direct parameter for.
extension CGImage {
    // Multiplies the RGB channels by `factor` (alpha unchanged).
    func multiplied(by factor: SIMD3<Float>) throws -> CGImage {
        try colorMatrix(scale: factor, bias: .zero, colorManaged: true)
    }

    // Normal map scale per glTF: xy *= scale. In [0,1] encoding that is
    // n' = scale * n + (1 - scale) / 2 on R and G; B unchanged.
    func normalScaled(by scale: Float) throws -> CGImage {
        let offset = (1 - scale) / 2
        return try colorMatrix(scale: [scale, scale, 1], bias: [offset, offset, 0], colorManaged: false)
    }

    // Occlusion strength per glTF: ao' = 1 + strength * (ao - 1).
    func occlusionAdjusted(strength: Float) throws -> CGImage {
        let offset = 1 - strength
        return try colorMatrix(scale: [strength, strength, strength], bias: [offset, offset, offset], colorManaged: false)
    }

    // out.rgb = in.rgb * scale + bias. Data textures (normal/AO) must skip color
    // management, otherwise sRGB<->linear conversion distorts the bias.
    private func colorMatrix(scale: SIMD3<Float>, bias: SIMD3<Float>, colorManaged: Bool) throws -> CGImage {
        let filter = CIFilter(name: "CIColorMatrix")!
        let input = colorManaged ? CIImage(cgImage: self) : CIImage(cgImage: self, options: [.colorSpace: NSNull()])
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(CIVector(x: CGFloat(scale.x), y: 0, z: 0, w: 0), forKey: "inputRVector")
        filter.setValue(CIVector(x: 0, y: CGFloat(scale.y), z: 0, w: 0), forKey: "inputGVector")
        filter.setValue(CIVector(x: 0, y: 0, z: CGFloat(scale.z), w: 0), forKey: "inputBVector")
        filter.setValue(CIVector(x: CGFloat(bias.x), y: CGFloat(bias.y), z: CGFloat(bias.z), w: 0), forKey: "inputBiasVector")
        let context = colorManaged ? CIContext() : CIContext(options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
        guard let output = filter.outputImage,
              let image = context.createCGImage(output, from: output.extent) else {
            throw GLTFError.unsupported("Core Image could not adjust a \(width)x\(height) texture")
        }
        return image
    }
}

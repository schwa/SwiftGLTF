import CoreGraphics
import CoreImage
import Foundation

enum ImageChannel {
    case red
    case green
    case blue
}

// Per-pixel texture adjustments shared by the SceneKit and RealityKit generators,
// for glTF factors that a renderer has no direct parameter for.
extension CGImage {
    // Multiplies the RGB channels by `factor` (alpha unchanged).
    func multiplied(by factor: SIMD3<Float>) throws -> CGImage {
        try colorMatrix(
            rows: [[factor.x, 0, 0], [0, factor.y, 0], [0, 0, factor.z]],
            bias: .zero,
            colorManaged: true
        )
    }

    // Normal map scale per glTF: xy *= scale. In [0,1] encoding that is
    // n' = scale * n + (1 - scale) / 2 on R and G; B unchanged.
    func normalScaled(by scale: Float) throws -> CGImage {
        let offset = (1 - scale) / 2
        return try colorMatrix(
            rows: [[scale, 0, 0], [0, scale, 0], [0, 0, 1]],
            bias: [offset, offset, 0],
            colorManaged: false
        )
    }

    // Occlusion strength per glTF: ao' = 1 + strength * (ao - 1).
    func occlusionAdjusted(strength: Float) throws -> CGImage {
        let offset = 1 - strength
        return try colorMatrix(
            rows: [[strength, 0, 0], [0, strength, 0], [0, 0, strength]],
            bias: [offset, offset, offset],
            colorManaged: false
        )
    }

    // One channel as a gray image, for glTF's packed data textures (metallic in
    // B, roughness in G, occlusion in R). Not color managed: these are data, and
    // an sRGB<->linear round trip would shift the values.
    func extracting(_ channel: ImageChannel) throws -> CGImage {
        let selector: SIMD3<Float>
        switch channel {
        case .red: selector = [1, 0, 0]
        case .green: selector = [0, 1, 0]
        case .blue: selector = [0, 0, 1]
        }
        return try colorMatrix(rows: [selector, selector, selector], bias: .zero, colorManaged: false)
    }

    // out.rgb = rows * in.rgb + bias (alpha unchanged); `rows` holds the R, G and
    // B output rows. Data textures must skip color management, otherwise
    // sRGB<->linear conversion distorts the values.
    private func colorMatrix(
        rows: [SIMD3<Float>],
        bias: SIMD3<Float>,
        colorManaged: Bool
    ) throws -> CGImage {
        func vector(_ row: SIMD3<Float>) -> CIVector {
            CIVector(x: CGFloat(row.x), y: CGFloat(row.y), z: CGFloat(row.z), w: 0)
        }
        let filter = CIFilter(name: "CIColorMatrix")!
        let input = colorManaged ? CIImage(cgImage: self) : CIImage(cgImage: self, options: [.colorSpace: NSNull()])
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(vector(rows[0]), forKey: "inputRVector")
        filter.setValue(vector(rows[1]), forKey: "inputGVector")
        filter.setValue(vector(rows[2]), forKey: "inputBVector")
        filter.setValue(CIVector(x: CGFloat(bias.x), y: CGFloat(bias.y), z: CGFloat(bias.z), w: 0), forKey: "inputBiasVector")
        let context = colorManaged ? CIContext() : CIContext(options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
        guard let output = filter.outputImage,
              let image = context.createCGImage(output, from: output.extent) else {
            throw GLTFError.unsupported("Core Image could not adjust a \(width)x\(height) texture")
        }
        return image
    }
}

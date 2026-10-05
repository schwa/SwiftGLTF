import AppKit
import ArgumentParser
import CoreGraphics
import Foundation
import Metal
import RealityKit
import SceneKit
import SwiftGLTF

enum Backend: String, ExpressibleByArgument {
    case scenekit
    case realitykit
}

@main
struct GLTFRender: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "gltf-render",
        abstract: "Render a glTF/GLB model to a PNG using SceneKit or RealityKit."
    )

    @Argument(help: "Path to the .gltf or .glb model.")
    var model: String

    @Option(name: [.short, .long], help: "Output PNG path.")
    var output = "/tmp/gltf-render.png"

    @Option(name: [.short, .long], help: "Output image size (square), in pixels.")
    var size = 1024

    @Option(name: [.short, .long], help: "Rendering backend: scenekit or realitykit.")
    var backend: Backend = .scenekit

    func run() async throws {
        let modelURL = URL(fileURLWithPath: model)
        let outputURL = URL(fileURLWithPath: output)
        let container = try Container(url: modelURL)

        let image: CGImage
        switch backend {
        case .scenekit:
            image = try renderSceneKit(container: container, size: size)
        case .realitykit:
            image = try await MainActor.run {
                try renderRealityKit(container: container, size: size)
            }
        }

        let rep = NSBitmapImageRep(cgImage: image)
        guard let png = rep.representation(using: .png, properties: [:]) else {
            throw ValidationError("Failed to encode PNG")
        }
        try png.write(to: outputURL)
        print("wrote \(outputURL.path) (\(size)x\(size), \(backend.rawValue))")
    }
}

// MARK: - SceneKit

private func renderSceneKit(container: Container, size: Int) throws -> CGImage {
    let scene = try SceneKitGenerator(container: container).generateSCNScene()

    let (center, radius) = scene.rootNode.boundingSphere
    let r = CGFloat(max(radius, 0.001))
    let distance = r * 2.6 + 0.1
    let cameraNode = SCNNode()
    cameraNode.camera = SCNCamera()
    cameraNode.camera?.zNear = Double(r * 0.01)
    cameraNode.camera?.zFar = Double(distance + r * 6)
    cameraNode.camera?.wantsHDR = true
    cameraNode.position = SCNVector3(
        CGFloat(center.x) + distance * 0.7,
        CGFloat(center.y) + distance * 0.45,
        CGFloat(center.z) + distance
    )
    cameraNode.look(at: center)
    scene.rootNode.addChildNode(cameraNode)

    scene.lightingEnvironment.contents = gradientEnvironment()
    scene.lightingEnvironment.intensity = 2.0
    scene.background.contents = CGColor(gray: 0.12, alpha: 1)

    let keyLight = SCNNode()
    keyLight.light = SCNLight()
    keyLight.light?.type = .directional
    keyLight.light?.intensity = 900
    keyLight.light?.castsShadow = true
    keyLight.position = cameraNode.position
    keyLight.look(at: center)
    scene.rootNode.addChildNode(keyLight)

    guard let device = MTLCreateSystemDefaultDevice() else {
        throw ValidationError("No Metal device")
    }
    let renderer = SCNRenderer(device: device, options: nil)
    renderer.scene = scene
    renderer.pointOfView = cameraNode
    let image = renderer.snapshot(
        atTime: 0,
        with: CGSize(width: size, height: size),
        antialiasingMode: .multisampling4X
    )
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        throw ValidationError("Could not get CGImage from SceneKit render")
    }
    return cgImage
}

// MARK: - RealityKit

@MainActor
private func renderRealityKit(container: Container, size: Int) throws -> CGImage {
    guard let device = MTLCreateSystemDefaultDevice() else {
        throw ValidationError("No Metal device")
    }
    let root = try RealityKitGLTFGenerator(container: container).generateRootEntity()
    let bounds = root.visualBounds(relativeTo: nil)
    let center = bounds.center
    let radius = max(bounds.boundingRadius, 0.001)
    let distance = radius * 2.6 + 0.1

    let renderer = try RealityRenderer()
    renderer.cameraSettings.colorBackground = .color(CGColor(gray: 0.12, alpha: 1))
    renderer.entities.append(root)

    let keyLight = Entity()
    keyLight.components.set(DirectionalLightComponent(color: .white, intensity: 1200))
    keyLight.look(at: center, from: center + SIMD3<Float>(1, 2, 3) * radius, relativeTo: nil)
    renderer.entities.append(keyLight)

    let fill = Entity()
    fill.components.set(DirectionalLightComponent(color: .white, intensity: 400))
    fill.look(at: center, from: center + SIMD3<Float>(-2, 1, -1) * radius, relativeTo: nil)
    renderer.entities.append(fill)

    let camera = Entity()
    camera.components.set(PerspectiveCameraComponent())
    let cameraPosition = center + SIMD3<Float>(0.7, 0.45, 1).normalized * distance
    camera.look(at: center, from: cameraPosition, relativeTo: nil)
    renderer.entities.append(camera)
    renderer.activeCamera = camera

    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: .rgba8Unorm,
        width: size,
        height: size,
        mipmapped: false
    )
    descriptor.usage = [.renderTarget, .shaderRead]
    guard let texture = device.makeTexture(descriptor: descriptor) else {
        throw ValidationError("Could not make target texture")
    }

    let outputTexture = try RealityRenderer.CameraOutput(.singleProjection(colorTexture: texture))
    let semaphore = DispatchSemaphore(value: 0)
    try renderer.updateAndRender(
        deltaTime: 0,
        cameraOutput: outputTexture,
        onComplete: { _ in semaphore.signal() }
    )
    semaphore.wait()

    guard let cgImage = cgImage(from: texture) else {
        throw ValidationError("Could not read back texture")
    }
    return cgImage
}

// MARK: - Helpers

private extension SIMD3 where Scalar == Float {
    var normalized: SIMD3<Float> {
        let length = (x * x + y * y + z * z).squareRoot()
        return length > 0 ? self / length : self
    }
}

private func gradientEnvironment(width: Int = 512, height: Int = 256) -> CGImage {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    let colors = [
        CGColor(red: 0.95, green: 0.97, blue: 1.0, alpha: 1),
        CGColor(red: 0.55, green: 0.60, blue: 0.70, alpha: 1),
        CGColor(red: 0.18, green: 0.18, blue: 0.20, alpha: 1)
    ] as CFArray
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 0.5, 1])!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: height),
        end: .zero,
        options: []
    )
    return context.makeImage()!
}

private func cgImage(from texture: MTLTexture) -> CGImage? {
    let width = texture.width
    let height = texture.height
    let bytesPerRow = width * 4
    var data = [UInt8](repeating: 0, count: bytesPerRow * height)
    texture.getBytes(
        &data,
        bytesPerRow: bytesPerRow,
        from: MTLRegionMake2D(0, 0, width, height),
        mipmapLevel: 0
    )
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    guard let context = CGContext(
        data: &data,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: bitmapInfo.rawValue
    ) else {
        return nil
    }
    return context.makeImage()
}

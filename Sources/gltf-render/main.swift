import AppKit
import CoreGraphics
import Foundation
import SceneKit
import SwiftGLTF

// Usage: gltf-render <model.gltf|.glb> [out.png] [size]
let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    print("usage: gltf-render <model.gltf|.glb> [out.png] [size]")
    exit(1)
}
let modelURL = URL(fileURLWithPath: arguments[1])
let outputURL = URL(fileURLWithPath: arguments.count >= 3 ? arguments[2] : "/tmp/gltf-render.png")
let size = arguments.count >= 4 ? (Int(arguments[3]) ?? 1024) : 1024

// A simple vertical gradient used as an image-based lighting environment so PBR
// (especially metallic) surfaces have something to reflect.
func gradientEnvironment(width: Int = 512, height: Int = 256) -> CGImage {
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
        CGColor(red: 0.95, green: 0.97, blue: 1.0, alpha: 1), // sky
        CGColor(red: 0.55, green: 0.60, blue: 0.70, alpha: 1), // horizon
        CGColor(red: 0.18, green: 0.18, blue: 0.20, alpha: 1) // ground
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

let container = try Container(url: modelURL)
let scene = try SceneKitGenerator(container: container).generateSCNScene()

// Frame the camera from the scene's bounding sphere.
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
    print("no Metal device")
    exit(1)
}
let renderer = SCNRenderer(device: device, options: nil)
renderer.scene = scene
renderer.pointOfView = cameraNode

let image = renderer.snapshot(
    atTime: 0,
    with: CGSize(width: size, height: size),
    antialiasingMode: .multisampling4X
)

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    print("failed to encode PNG")
    exit(1)
}
try png.write(to: outputURL)
print("wrote \(outputURL.path) (\(size)x\(size))")

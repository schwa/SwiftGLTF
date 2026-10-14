import Foundation
import SwiftGLTF
import Testing

struct CameraInitTests {
    @Test
    func perspectiveCameraBuiltByClientRoundTrips() throws {
        let camera = Camera(perspective: .init(aspectRatio: 1.5, yfov: 0.8, zfar: 100, znear: 0.1), name: "cam")
        #expect(camera.type == .perspective)
        let data = try JSONEncoder().encode(camera)
        let decoded = try JSONDecoder().decode(Camera.self, from: data)
        #expect(decoded == camera)
    }

    @Test
    func orthographicCameraBuiltByClientRoundTrips() throws {
        let camera = Camera(orthographic: .init(xmag: 1, ymag: 2, zfar: 10, znear: 0.01))
        #expect(camera.type == .orthographic)
        let data = try JSONEncoder().encode(camera)
        let decoded = try JSONDecoder().decode(Camera.self, from: data)
        #expect(decoded == camera)
    }
}

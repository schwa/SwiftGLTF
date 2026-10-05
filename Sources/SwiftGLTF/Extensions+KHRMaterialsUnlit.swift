import Foundation

// KHR_materials_unlit: render the material without lighting (constant shading).
// https://github.com/KhronosGroup/glTF/tree/main/extensions/2.0/Khronos/KHR_materials_unlit
public struct KHRMaterialsUnlit: GLTFExtension {
    public static let extensionName = "KHR_materials_unlit"
}

public extension Material {
    var isUnlit: Bool {
        (try? extensionValue(KHRMaterialsUnlit.self)) != nil
    }
}

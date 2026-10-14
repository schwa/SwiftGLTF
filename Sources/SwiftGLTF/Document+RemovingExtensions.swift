import Foundation

public extension Document {
    // Returns a copy with the named extensions removed from every object and
    // from `extensionsUsed` / `extensionsRequired`. Empty `extensions` maps become nil.
    func removingExtensions(_ names: Set<String>, keepingDeclarations: Bool = false) -> Document {
        guard !names.isEmpty else {
            return self
        }
        func strip(_ extensions: inout Extensions?) {
            guard let values = extensions?.values else {
                return
            }
            let kept = values.filter { !names.contains($0.key) }
            if kept.count != values.count {
                extensions = kept.isEmpty ? nil : Extensions(kept)
            }
        }
        func strip(_ info: inout TextureInfo?) {
            strip(&info, \.extensions)
        }
        func strip<T>(_ value: inout T?, _ keyPath: WritableKeyPath<T, Extensions?>) {
            guard var unwrapped = value else {
                return
            }
            strip(&unwrapped[keyPath: keyPath])
            value = unwrapped
        }

        var document = self
        if !keepingDeclarations {
            document.extensionsUsed.removeAll { names.contains($0) }
            document.extensionsRequired.removeAll { names.contains($0) }
        }
        strip(&document.extensions)
        strip(&document.asset.extensions)

        for index in document.accessors.indices {
            strip(&document.accessors[index].extensions)
            if var sparse = document.accessors[index].sparse {
                strip(&sparse.extensions)
                strip(&sparse.indices.extensions)
                strip(&sparse.values.extensions)
                document.accessors[index].sparse = sparse
            }
        }
        for index in document.animations.indices {
            strip(&document.animations[index].extensions)
            for channel in document.animations[index].channels.indices {
                strip(&document.animations[index].channels[channel].extensions)
                strip(&document.animations[index].channels[channel].target.extensions)
            }
            for sampler in document.animations[index].samplers.indices {
                strip(&document.animations[index].samplers[sampler].extensions)
            }
        }
        for index in document.buffers.indices {
            strip(&document.buffers[index].extensions)
        }
        for index in document.bufferViews.indices {
            strip(&document.bufferViews[index].extensions)
        }
        for index in document.cameras.indices {
            strip(&document.cameras[index].extensions)
            strip(&document.cameras[index].perspective, \.extensions)
            strip(&document.cameras[index].orthographic, \.extensions)
        }
        for index in document.images.indices {
            strip(&document.images[index].extensions)
        }
        for index in document.materials.indices {
            strip(&document.materials[index].extensions)
            if var pbr = document.materials[index].pbrMetallicRoughness {
                strip(&pbr.extensions)
                strip(&pbr.baseColorTexture)
                strip(&pbr.metallicRoughnessTexture)
                document.materials[index].pbrMetallicRoughness = pbr
            }
            strip(&document.materials[index].normalTexture)
            strip(&document.materials[index].occlusionTexture)
            strip(&document.materials[index].emissiveTexture)
        }
        for index in document.meshes.indices {
            strip(&document.meshes[index].extensions)
            for primitive in document.meshes[index].primitives.indices {
                strip(&document.meshes[index].primitives[primitive].extensions)
            }
        }
        for index in document.nodes.indices {
            strip(&document.nodes[index].extensions)
        }
        for index in document.samplers.indices {
            strip(&document.samplers[index].extensions)
        }
        for index in document.scenes.indices {
            strip(&document.scenes[index].extensions)
        }
        for index in document.skins.indices {
            strip(&document.skins[index].extensions)
        }
        for index in document.textures.indices {
            strip(&document.textures[index].extensions)
        }
        return document
    }
}

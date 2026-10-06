import Foundation

/// Supplies the bytes of buffer views that a compression extension replaces, such as EXT_meshopt_compression, whose
/// views name a compressed source and whose own buffer may be a placeholder without data.
///
/// Register decoders on a ``Container``; ``Container/data(for:)-(BufferView)`` and accessor reads ask them, in order,
/// before slicing the view's buffer.
public protocol BufferViewDecoder: Sendable {
    /// The glTF extensions this decoder implements, e.g. "EXT_meshopt_compression".
    var extensionNames: Set<String> { get }

    /// The view's decoded bytes (`bufferView.byteLength` long), or nil to leave the view to the next decoder and then
    /// to its buffer. `container` gives access to other buffers, e.g. the compressed source.
    func data(for bufferView: BufferView, in container: Container) throws -> Data?
}

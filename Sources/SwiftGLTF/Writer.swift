import Foundation

public extension Document {
    func jsonData(prettyPrinted: Bool = false) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = prettyPrinted ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
        return try encoder.encode(self)
    }
}

public enum GLTFWriter {
    // Assembles a GLB from a JSON chunk and an optional BIN chunk.
    public static func glbData(json: Data, binary: Data?) -> Data {
        func padded(_ data: Data, with byte: UInt8) -> Data {
            var data = data
            while !data.count.isMultiple(of: 4) {
                data.append(byte)
            }
            return data
        }
        func uint32(_ value: Int) -> Data {
            withUnsafeBytes(of: UInt32(value).littleEndian) { Data($0) }
        }
        let jsonChunk = padded(json, with: 0x20) // spaces
        var body = uint32(jsonChunk.count) + uint32(0x4E4F_534A) + jsonChunk
        if let binary {
            let binChunk = padded(binary, with: 0)
            body += uint32(binChunk.count) + uint32(0x004E_4942) + binChunk
        }
        return uint32(0x4654_6C67) + uint32(2) + uint32(12 + body.count) + body
    }
}

public extension Container {
    // Image bytes whether referenced by uri (file/data URL) or a buffer view.
    func data(for image: Image) throws -> Data {
        if let uri = image.uri {
            return try data(for: uri)
        }
        if let bufferView = try image.bufferView?.resolve(in: document) {
            return try data(for: bufferView)
        }
        throw GLTFError.missingResource("Image has neither uri nor bufferView")
    }

    // Writes the model to `url`; the format follows the extension (.glb / .gltf).
    // For .gltf, `embedResources` stores buffers and external images as data URIs
    // (self-contained); otherwise URIs are kept, relative files are copied next to
    // the output, and a GLB BIN chunk is written as a sidecar .bin.
    func write(to url: URL, embedResources: Bool = true) throws {
        switch url.pathExtension.lowercased() {
        case "glb":
            try writeGLB(to: url)
        case "gltf":
            try writeGLTF(to: url, embedResources: embedResources)
        default:
            throw GLTFError.unsupported("Unsupported output extension '\(url.pathExtension)'")
        }
    }

    private func jsonObject() throws -> [String: JSONValue] {
        // The output is the document alone; the source file is not consulted.
        guard case let .object(object) = try JSONDecoder().decode(JSONValue.self, from: document.jsonData()) else {
            throw GLTFError.invalidDocument("Document did not encode to a JSON object")
        }
        return object
    }

    private func encoded(_ object: [String: JSONValue], prettyPrinted: Bool) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = prettyPrinted ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
        return try encoder.encode(JSONValue.object(object))
    }

    // Buffers stay one-to-one, so buffer and bufferView indices and offsets are unchanged:
    // buffer 0 becomes the BIN chunk, and other buffers with data are embedded as data URIs.
    private func writeGLB(to url: URL) throws {
        var object = try jsonObject()
        var buffers: [JSONValue] = {
            if case let .array(buffers)? = object["buffers"] {
                return buffers
            }
            return []
        }()
        var binary = Data()
        for (index, buffer) in document.buffers.enumerated() {
            guard case var .object(fields) = buffers[index] else { continue }
            if index == 0 {
                if hasBytes(bufferAt: 0) {
                    binary = try data(for: buffer).prefix(buffer.byteLength)
                }
                fields["uri"] = nil
            }
            else if hasBytes(bufferAt: index) {
                let bytes = try data(for: buffer).prefix(buffer.byteLength)
                fields["uri"] = .string("data:application/octet-stream;base64,\(bytes.base64EncodedString())")
            }
            buffers[index] = .object(fields)
        }
        try embedImages(in: &object, binary: &binary)
        let hasBinary = !buffers.isEmpty || !binary.isEmpty
        if hasBinary {
            var first: [String: JSONValue] = [:]
            if case let .object(fields)? = buffers.first {
                first = fields
            }
            first["byteLength"] = .number(Double(binary.count))
            if buffers.isEmpty {
                buffers.append(.object(first))
            }
            else {
                buffers[0] = .object(first)
            }
            object["buffers"] = .array(buffers)
        }
        let glb = GLTFWriter.glbData(
            json: try encoded(object, prettyPrinted: false),
            binary: hasBinary ? binary : nil
        )
        try glb.write(to: url)
    }

    // Whether the buffer has bytes: a uri, or the BIN chunk of a GLB. Others are placeholders.
    private func hasBytes(bufferAt index: Int) -> Bool {
        if document.buffers[index].uri != nil {
            return true
        }
        if index == 0, case .binary = kind {
            return true
        }
        return false
    }

    // A GLB is self-contained: images referenced by uri move into the BIN chunk as new buffer views.
    private func embedImages(in object: inout [String: JSONValue], binary: inout Data) throws {
        guard case let .array(images)? = object["images"] else {
            return
        }
        var views: [JSONValue] = {
            if case let .array(views)? = object["bufferViews"] {
                return views
            }
            return []
        }()
        object["images"] = .array(try zip(images, document.images).map { value, image in
            guard case var .object(fields) = value, let uri = image.uri else {
                return value
            }
            while !binary.count.isMultiple(of: 4) {
                binary.append(0)
            }
            let bytes = try data(for: image)
            var view: [String: JSONValue] = ["buffer": .number(0), "byteLength": .number(Double(bytes.count))]
            if !binary.isEmpty {
                view["byteOffset"] = .number(Double(binary.count))
            }
            binary += bytes
            views.append(.object(view))
            fields["uri"] = nil
            fields["bufferView"] = .number(Double(views.count - 1))
            fields["mimeType"] = .string(image.mimeType ?? Self.mimeType(for: uri))
            return .object(fields)
        })
        object["bufferViews"] = .array(views)
    }

    // GLB images need a mimeType; guess it from the uri when the source has none.
    static func mimeType(for uri: URI) -> String {
        let lowercased = uri.string.lowercased()
        if lowercased.hasPrefix("data:"), let end = lowercased.firstIndex(of: ";") ?? lowercased.firstIndex(of: ",") {
            return String(lowercased[lowercased.index(lowercased.startIndex, offsetBy: 5) ..< end])
        }
        if lowercased.hasSuffix(".png") {
            return "image/png"
        }
        if lowercased.hasSuffix(".webp") {
            return "image/webp"
        }
        return "image/jpeg"
    }

    private func writeGLTF(to url: URL, embedResources: Bool) throws {
        var object = try jsonObject()
        let directory = url.deletingLastPathComponent()
        let sourceDirectory = self.url.deletingLastPathComponent()

        func copyRelative(_ uri: String) throws {
            guard URL(string: uri)?.scheme == nil,
                  directory.standardizedFileURL != sourceDirectory.standardizedFileURL else {
                return
            }
            // The JSON keeps the encoded URI; the file system needs the decoded path.
            let path = URI.decodedPath(uri)
            let source = sourceDirectory.appendingPathComponent(path)
            let destination = directory.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: source, to: destination)
        }

        var buffers: [JSONValue] = []
        for (index, buffer) in document.buffers.enumerated() {
            var fields: [String: JSONValue] = ["byteLength": .number(Double(buffer.byteLength))]
            if let name = buffer.name { fields["name"] = .string(name) }
            if case let .array(existing)? = object["buffers"], case let .object(original) = existing[index] {
                fields["extensions"] = original["extensions"]
                fields["extras"] = original["extras"]
            }
            if !hasBytes(bufferAt: index) {
                // A placeholder such as an EXT_meshopt_compression fallback buffer: no uri, nothing to write.
            }
            else if embedResources {
                let bytes = try data(for: buffer).prefix(buffer.byteLength)
                fields["uri"] = .string("data:application/octet-stream;base64,\(bytes.base64EncodedString())")
            }
            else if let uri = buffer.uri {
                try copyRelative(uri.string)
                fields["uri"] = .string(uri.string)
            }
            else {
                // GLB BIN chunk: write a sidecar .bin.
                let name = "\(url.deletingPathExtension().lastPathComponent)\(index == 0 ? "" : "-\(index)").bin"
                try data(for: buffer).prefix(buffer.byteLength).write(to: directory.appendingPathComponent(name))
                fields["uri"] = .string(name)
            }
            buffers.append(.object(fields))
        }
        if !buffers.isEmpty {
            object["buffers"] = .array(buffers)
        }

        if case let .array(images)? = object["images"] {
            object["images"] = .array(try zip(images, document.images).map { value, image in
                guard case var .object(fields) = value, let uri = image.uri, URL(string: uri.string)?.scheme != "data" else {
                    return value
                }
                if embedResources {
                    let bytes = try data(for: image)
                    let mimeType = image.mimeType ?? Self.mimeType(for: uri)
                    fields["uri"] = .string("data:\(mimeType);base64,\(bytes.base64EncodedString())")
                }
                else {
                    try copyRelative(uri.string)
                }
                return .object(fields)
            })
        }

        try encoded(object, prettyPrinted: true).write(to: url)
    }
}

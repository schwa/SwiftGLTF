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
        let value = try JSONDecoder().decode(JSONValue.self, from: document.jsonData())
        guard case let .object(object) = value else {
            throw GLTFError.invalidDocument("Document did not encode to a JSON object")
        }
        return object
    }

    private func encoded(_ object: [String: JSONValue], prettyPrinted: Bool) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = prettyPrinted ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
        return try encoder.encode(JSONValue.object(object))
    }

    // Packs every buffer into one BIN chunk (4-byte aligned) and rewrites the
    // buffers/bufferViews accordingly.
    private func writeGLB(to url: URL) throws {
        var object = try jsonObject()
        var binary = Data()
        var offsets: [Int] = []
        for buffer in document.buffers {
            while !binary.count.isMultiple(of: 4) {
                binary.append(0)
            }
            offsets.append(binary.count)
            binary += try data(for: buffer).prefix(buffer.byteLength)
        }
        if !document.buffers.isEmpty {
            object["buffers"] = .array([.object(["byteLength": .number(Double(binary.count))])])
        }
        if case let .array(views)? = object["bufferViews"] {
            object["bufferViews"] = .array(views.map { view in
                guard case var .object(fields) = view,
                      case let .number(bufferIndex)? = fields["buffer"] else {
                    return view
                }
                let base: Double = {
                    if case let .number(offset)? = fields["byteOffset"] {
                        return offset
                    }
                    return 0
                }()
                fields["buffer"] = .number(0)
                let shifted = base + Double(offsets[Int(bufferIndex)])
                fields["byteOffset"] = shifted == 0 ? nil : .number(shifted)
                return .object(fields)
            })
        }
        let glb = GLTFWriter.glbData(
            json: try encoded(object, prettyPrinted: false),
            binary: document.buffers.isEmpty ? nil : binary
        )
        try glb.write(to: url)
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
            let source = sourceDirectory.appendingPathComponent(uri)
            let destination = directory.appendingPathComponent(uri)
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
            if embedResources {
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
                    let mimeType = image.mimeType ?? (uri.string.lowercased().hasSuffix(".png") ? "image/png" : "image/jpeg")
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

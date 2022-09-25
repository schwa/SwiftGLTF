import Foundation
import SwiftGLTF

import SwiftUI

struct GLTFInspectorView: View {
    let container: Container

    init(container: Container) {
        self.container = container
    }

    @State
    var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            InspectorPageView(navigationPath: $navigationPath) {
                Form {
                    ContainerView(container: container)
                }
                .padding()
            }
            .navigationDestination(for: KeyPath<Document, [Accessor]>.self) { _ in
                InspectorPageView(navigationPath: $navigationPath) {
                    Text("ACCESSORS")
                }
            }
            .navigationDestination(for: KeyPath<Document, [Buffer]>.self) { _ in
                InspectorPageView(navigationPath: $navigationPath) {
                    ScrollView {
                        Form {
                            ForEach(container.document.buffers.indexed, id: \.index) { index, buffer in
                                Section("Buffer #\(index)") {
                                    BufferView(buffer: buffer)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
        }
    }
}

// MARK: -

struct ContainerView: View {
    let container: Container

    var body: some View {
        Section("Container") {
            LabeledContent("URL") {
                Text(verbatim: container.url.lastPathComponent)
            }
            LabeledContent("Kind") {
                switch container.kind {
                case .json:
                    Text("Text (JSON)")
                case .binary:
                    Text("Binary (GLB)")
                }
            }
        }
        //        if case .binary(let glb) = container.kind {
        //        }
        Divider()
        DocumentView(document: container.document)
        Toggle("test", isOn: .constant(true))
    }
}

struct DocumentView: View {
    let document: Document
    var body: some View {
        Section("Document") {
            LabeledContent("Extensions Used") {
                if !document.extensionsRequired.isEmpty {
                    JSONView(document.extensionsRequired)
                }
            }
            LabeledContent("Extensions Required") {
                if !document.extensionsRequired.isEmpty {
                    JSONView(document.extensionsRequired)
                }
            }
            LabeledContent("Accessors") {
                NavigationLink("\(document.accessors.count) accessor(s)", value: \Document.accessors)
                    .buttonStyle(XButtonStyle())
            }
            LabeledContent("Animations") {
                NavigationLink("\(document.animations.count) animation(s)", value: \Document.animations)
                    .buttonStyle(XButtonStyle())
            }
            LabeledContent("Buffers") {
                NavigationLink(value: \Document.buffers) {
                    Text("\(document.buffers.count) buffer(s)")
                }
                .buttonStyle(XButtonStyle())
            }
        }
        Divider()
        Section("Asset") {
            AssetView(asset: document.asset)
        }
    }
}

//
struct XButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 0) {
            configuration.label
            Image(systemName: "arrow.forward.circle.fill").controlSize(.mini)
        }
        .foregroundColor(.accentColor)
    }
}

struct AssetView: View {
    let asset: Asset

    var body: some View {
        LabeledContent("Copyright") {
            Text(asset.copyright ?? "")
        }
        LabeledContent("Generator") {
            Text(asset.generator ?? "")
        }
        LabeledContent("Min Version") {
            Text(asset.minVersion?.rawValue ?? "")
        }
        LabeledContent("Version") {
            Text(asset.version.rawValue)
        }
    }
}

struct AccessorView {
}

struct BufferView: View {
    let buffer: Buffer

    var body: some View {
        LabeledContent("Name") {
            Text(buffer.name ?? "")
        }
        LabeledContent("Length") {
            Text("\(buffer.byteLength, format: .number)")
        }
        LabeledContent("URI") {
            Text(verbatim: buffer.uri?.string ?? "")
        }
    }
}

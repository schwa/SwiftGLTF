import Foundation

import CoreGraphics
import ImageIO
import RealityKit
import SceneKit
import SwiftGLTF
import SwiftUI
import Zip

struct ContentView: View {
    var body: some View {
        DownloaderView()
    }
}

struct DownloaderView: View {
    let applicationSupportDirectory = FileManager().urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    let url = URL(string: "https://codeload.github.com/KhronosGroup/glTF-Sample-Models/zip/refs/heads/main")!

    enum DownloadState {
        case waiting
        case downloading
        case downloaded(URL)
    }
    
    @State
    var state: DownloadState = .waiting
    
    var body: some View {
        VStack {
            switch state {
            case .waiting:
                Text("This downloads approximate 1.1GB of data from [https://codeload.github.com/KhronosGroup/glTF-Sample-Models/zip/refs/heads/main](https://codeload.github.com/KhronosGroup/glTF-Sample-Models/zip/refs/heads/main) and stores it in \(applicationSupportDirectory.path)")
                    .textSelection(.enabled)
                Button("Download") {
                    state = .downloading
                    Task {
                        do {
                            let (url, _) = try await URLSession.shared.download(for: URLRequest(url: url))
                            let finalDestination = applicationSupportDirectory.appendingPathComponent("glTF-Sample-Models")
                            try await Self.unpack(url, to: finalDestination)
                            print(finalDestination)
                            
                            state = .downloaded(finalDestination.deletingPathExtension())
                        }
                        catch {
                            print(error)
                            state = .waiting
                        }
                    }
                }
            case .downloading:
                ProgressView()
            case .downloaded(let url):
                GLTFModelBrowser(url: url)
            }
        }
        .onAppear {
            let finalDestination = applicationSupportDirectory.appendingPathComponent("glTF-Sample-Models")
            if FileManager().fileExists(atPath: finalDestination.path) {
                state = .downloaded(finalDestination)
            }
        }

    }

    // Moving and unzipping ~1.1 GB is slow synchronous work; run it off the main
    // actor so the UI stays responsive (the Task above inherits main-actor isolation).
    @concurrent
    private static func unpack(_ downloaded: URL, to destination: URL) async throws {
        let archive = downloaded.appendingPathExtension("zip")
        try FileManager().moveItem(at: downloaded, to: archive)
        try Zip.unzipFile(archive, destination: destination, overwrite: true, password: nil)
    }
}

struct GLTFModelBrowser: View {
    @MainActor
    final class Model: ObservableObject {
        var rootURL: URL?
        
        @Published
        var modelInfo: [ModelInfo] = []
        
        func load() {
            // https://codeload.github.com/KhronosGroup/glTF-Sample-Models/zip/refs/heads/main
            //            rootURL = URL(fileURLWithPath: "/Users/schwa/Shared/Unorganised/glTF-Sample-Models/2.0")
            guard let rootURL = rootURL else {
                fatalError()
            }
            let url = rootURL.appendingPathComponent("model-index.json")
            
            let d = try! Data(contentsOf: url)
            modelInfo = try! JSONDecoder().decode([ModelInfo].self, from: d)
        }
        
        func screenshot(for model: ModelInfo) throws -> SwiftUI.Image {
            guard let rootURL = rootURL else {
                fatalError()
            }
            let url = rootURL.appendingPathComponent(model.name).appendingPathComponent(model.screenshot)
            return Image(decorative: try cgImage(contentsOf: url), scale: 1)
        }
    }
    
    @StateObject
    var model = Model()
    
    var url: URL
    
    init(url: URL) {
        self.url = url
    }
    
    var body: some View {
        let cells = model.modelInfo.map { Cell.model($0) }
        NavigationView {
            List(cells, id: \.self, children: \.children) { cell in
                switch cell {
                case .model(let modelInfo):
                    Text(modelInfo.name)
                case .variant(let modelInfo, let variant):
                    NavigationLink(variant) {
                        let url = model.rootURL!.appendingPathComponent(modelInfo.name).appendingPathComponent(variant).appendingPathComponent(modelInfo.variants[variant]!)
#if os(macOS)
                        HSplitView {
                            GLTFViewer(url: url)
                            GLTFInspectorView(container: try! Container(url: url))
                                .frame(minWidth: 160, maxHeight: .infinity)
                        }
#elseif os(iOS)
                        GLTFViewer(url: url)
#endif
                    }
                }
            }
        }
        .onAppear {
            model.rootURL = url.appending(component: "glTF-Sample-Models-main/2.0")
            model.load()
        }
    }
}

enum Cell: Hashable {
    case model(ModelInfo)
    case variant(ModelInfo, String)
    
    var children: [Cell]? {
        switch self {
        case .model(let modelInfo):
            return modelInfo.variants.keys.map { .variant(modelInfo, $0) }
        case .variant:
            return nil
        }
    }
}

struct VariantPicker: View {
    let rootURL: URL
    let modelInfo: ModelInfo
    
    @State
    var variant: String?
    
    var body: some View {
        VStack {
            Text(modelInfo.name)
            
            Picker("Variant", selection: $variant) {
                ForEach(Array(modelInfo.variants.keys), id: \.self) { variant in
                    Text(variant).tag(Optional(variant))
                }
            }
            variant.map { variant in
                GLTFViewer(url: rootURL.appendingPathComponent(modelInfo.name).appendingPathComponent(variant).appendingPathComponent(modelInfo.variants[variant]!))
            }
            Spacer()
        }
    }
}

struct ModelInfo: Identifiable, Decodable, Hashable {
    var id: String {
        name
    }
    
    let name: String
    let screenshot: String
    let variants: [String: String]
}

struct EntityView: View {
    let rootEntity: Entity
    
    var body: some View {
        ARViewAdaptor {
            let arView = ARView()
            
#if os(macOS)
            arView.environment.background = .color(NSColor.blue.blended(withFraction: 0.4, of: .green) ?? .blue)
#endif
            
            let rootAnchor = AnchorEntity()
            arView.scene.addAnchor(rootAnchor)
            rootAnchor.addChild(rootEntity)
            
            let camera = PerspectiveCamera()
            camera.look(at: [0, 0, 0], from: [0.3, 0.3, 0.5], relativeTo: nil)
            rootAnchor.addChild(camera)
            
            return arView
        } update: { _ in
        }
    }
}

struct GLTFViewer: View {
    let url: URL
    
    init(url: URL) {
        self.url = url
    }
    
    var body: some View {
        let container = try! Container(url: url)
        let entity = try! RealityKitGLTFGenerator(container: container).generateRootEntity()
        EntityView(rootEntity: entity)
    }
}

struct GLTFOutlineVIew: View {
    let url: URL
    
    var body: some View {
        let container = try! Container(url: url)
        ScrollView {
            DisclosureGroup("Document") {
                let document = container.document
                AssetView(asset: document.asset)
            }
        }
        .background(Color.white)
    }
}

func cgImage(contentsOf url: URL) throws -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw CocoaError(.fileReadCorruptFile)
    }
    return image
}

#if os(macOS)
struct ARViewAdaptor<ViewType: NSView>: NSViewRepresentable {
    let make: () -> ViewType
    let update: (ViewType) -> Void

    init(make: @escaping () -> ViewType, update: @escaping (ViewType) -> Void) {
        self.make = make
        self.update = update
    }

    func makeNSView(context: Context) -> ViewType { make() }
    func updateNSView(_ view: ViewType, context: Context) { update(view) }
}
#elseif os(iOS)
struct ARViewAdaptor<ViewType: UIView>: UIViewRepresentable {
    let make: () -> ViewType
    let update: (ViewType) -> Void

    init(make: @escaping () -> ViewType, update: @escaping (ViewType) -> Void) {
        self.make = make
        self.update = update
    }

    func makeUIView(context: Context) -> ViewType { make() }
    func updateUIView(_ view: ViewType, context: Context) { update(view) }
}
#endif

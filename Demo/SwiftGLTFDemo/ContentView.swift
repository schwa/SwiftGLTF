import Foundation

import Everything
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
    let url = URL(string: "https://codeload.github.com/KhronosGroup/glTF-Sample-Models/zip/refs/heads/master")!
    
    enum DownloadState {
        case waiting
        case downloading
        case downloaded(URL)
    }
    
    @State
    var state: DownloadState = .waiting
    
    var body: some View {
        switch state {
        case .waiting:
            Button("Download") {
                state = .downloading
                Task {
                    do {
                        let (url, _) = try await URLSession.shared.download(for: URLRequest(url: url))
                        print(url)
                        let newURL = url.appendingPathExtension("zip")
                        try FileManager().moveItem(at: url, to: newURL)
                        try Zip.unzipFile(newURL, destination: newURL.deletingPathExtension(), overwrite: true, password: nil)
                        state = .downloaded(newURL.deletingPathExtension())
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
}

struct GLTFModelBrowser: View {
    class Model: ObservableObject {
        var rootURL: URL?
        
        @Published
        var modelInfo: [ModelInfo] = []
        
        func load() {
            // https://codeload.github.com/KhronosGroup/glTF-Sample-Models/zip/refs/heads/master
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
            return Image(cgImage: try ImageSource(url: url).image(at: 0))
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
            model.rootURL = url.appending(component: "glTF-Sample-Models-master/2.0")
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
        ViewAdaptor {
            let arView = ARView()
            
#if os(macOS)
            arView.environment.background = .color(.blue.blended(withFraction: 0.4, of: .green)!)
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

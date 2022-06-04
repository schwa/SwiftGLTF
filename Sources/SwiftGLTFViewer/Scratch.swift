import SwiftUI

extension Collection {
    var indexed: [(index: Int, element: Element)] {
        zip(0..<count, self).map { (index: $0.0, element: $0.1) }
    }
}

public struct InspectorPageView <Content>: View where Content: View {
    @Binding
    var navigationPath: NavigationPath

    let content: () -> Content

    public init(navigationPath: Binding<NavigationPath>, @ViewBuilder content: @escaping () -> Content) {
        self._navigationPath = navigationPath
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading) {
            if !navigationPath.isEmpty {
                Button("Back") {
                    navigationPath.removeLast()
                }
                .padding()
            }
            content()
        }
    }
}

struct JSONView <Content>: View where Content: Encodable {
    let jsonText: String

    init(_ content: Content) {
        let encoder = JSONEncoder()
        let data = try! encoder.encode(content)
        jsonText = String(bytes: data, encoding: .utf8)!
    }

    var body: some View {
        Text(verbatim: jsonText)
    }
}

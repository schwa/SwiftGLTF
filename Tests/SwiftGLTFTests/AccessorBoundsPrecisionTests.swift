import Foundation
import Testing

@testable import SwiftGLTF

// Accessor min/max are exact values and must survive decode -> encode (#46).
struct AccessorBoundsPrecisionTests {
    @Test
    func boundsRoundTripExactly() throws {
        // From AlphaBlendModeTest: as Float this rounds to a neighboring float32.
        let json = """
        { "asset": { "version": "2.0" },
          "accessors": [ { "componentType": 5126, "count": 1, "type": "VEC2",
                           "min": [0.8924999237060547, 0.6624999940395355], "max": [1, 2] } ] }
        """
        let document = try JSONDecoder().decode(Document.self, from: Data(json.utf8))
        let encoded = try JSONSerialization.jsonObject(with: document.jsonData()) as! [String: Any]
        let accessor = (encoded["accessors"] as! [[String: Any]])[0]
        let minimum = accessor["min"] as! [Double]
        #expect(minimum == [0.8924999237060547, 0.6624999940395355])
    }
}

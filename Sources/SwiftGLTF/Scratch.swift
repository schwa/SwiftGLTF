import CoreGraphics
import Foundation
import os
import simd

extension Array {
    init(withUnsafeData data: Data) {
        self = data.withUnsafeBytes { buffer in
            let buffer = buffer.bindMemory(to: Element.self)
            return Array(buffer)
        }
    }
}

internal extension SIMD4<Float> {
    var xyz: SIMD3<Float> {
        [x, y, z]
    }

    var cgColor: CGColor {
        CGColor(red: Double(x), green: Double(y), blue: Double(z), alpha: Double(w))
    }
}

extension simd_float4x4 {
    static let identity = simd_float4x4(diagonal: [1, 1, 1, 1])

    var scalars: [Float] {
        [
            self[0][0], self[1][0], self[2][0], self[3][0],
            self[0][1], self[1][1], self[2][1], self[3][1],
            self[0][2], self[1][2], self[2][2], self[3][2],
            self[0][3], self[1][3], self[2][3], self[3][3]
        ]
    }
}

internal func warning(_ message: @autoclosure () -> String? = Optional.none, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
    warning(false, message(), file: file, function: function, line: line)
}

internal func warning(_ closure: @autoclosure () -> Bool = false, _ message: @autoclosure () -> String? = Optional.none, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
    guard closure() == false else {
        return
    }

    let logger = Logger()
    if let message = message() {
        logger.debug("\(message)")
    }
    else {
        logger.debug("Warning! \(file)#\(line)")
    }
}

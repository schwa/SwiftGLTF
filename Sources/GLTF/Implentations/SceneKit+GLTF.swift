//
//  File.swift
//
//
//  Created by Jonathan Wight on 9/6/19.
//

import Everything
import Foundation
import SceneKit

extension SCNFilterMode {
    init(filter: Sampler.MagFilter) {
        switch filter {
        case .LINEAR:
            self = .linear
        case .NEAREST:
            self = .nearest
        }
    }
}

extension SCNFilterMode {
    init(filter: Sampler.MinFilter) {
        switch filter {
        case .LINEAR:
            self = .linear
        case .NEAREST:
            self = .nearest
        default:
            warning("No filter \(filter)")
            self = .linear
        }
    }
}

extension SCNWrapMode {
    init(_ mode: Sampler.Wrap) {
        switch mode {
        case .CLAMP_TO_EDGE:
            self = .clampToBorder
        case .MIRRORED_REPEAT:
            self = .mirror
        case .REPEAT:
            self = .repeat
        }
    }
}

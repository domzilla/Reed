//
//  ColorHash.swift
//  ColorHash
//
//  Created by Atsushi Nagase on 11/25/15.
//  Copyright © 2015 LittleApps Inc. All rights reserved.
//
// Original Project: https://github.com/ngs/color-hash.swift

import Foundation
import UIKit

public class ColorHash {
    public static let defaultSaturation = [CGFloat(0.35), CGFloat(0.5), CGFloat(0.65)]
    public static let defaultBrightness = [CGFloat(0.5), CGFloat(0.65), CGFloat(0.80)]

    let seed = CGFloat(131.0)
    let seed2 = CGFloat(137.0)
    let maxSafeInteger = 9_007_199_254_740_991.0 / CGFloat(137.0)
    let full = CGFloat(360.0)

    public private(set) var str: String
    public private(set) var brightness: [CGFloat]
    public private(set) var saturation: [CGFloat]

    public init(
        _ str: String,
        _ saturation: [CGFloat] = defaultSaturation,
        _ brightness: [CGFloat] = defaultBrightness
    ) {
        self.str = str
        self.saturation = saturation
        self.brightness = brightness
    }

    public var bkdrHash: CGFloat {
        var hash = CGFloat(0)
        for char in "\(self.str)x" {
            if let scl = String(char).unicodeScalars.first?.value {
                if hash > self.maxSafeInteger {
                    hash = hash / self.seed2
                }
                hash = hash * self.seed + CGFloat(scl)
            }
        }
        return hash
    }

    public var HSB: (CGFloat, CGFloat, CGFloat) {
        var hash = CGFloat(bkdrHash)
        let H = hash.truncatingRemainder(dividingBy: self.full - 1.0) / self.full
        hash /= self.full
        let S = self.saturation[Int((self.full * hash).truncatingRemainder(dividingBy: CGFloat(self.saturation.count)))]
        hash /= CGFloat(self.saturation.count)
        let B = self.brightness[Int((self.full * hash).truncatingRemainder(dividingBy: CGFloat(self.brightness.count)))]
        return (H, S, B)
    }

    public var color: UIColor {
        let (H, S, B) = self.HSB
        return UIColor(hue: H, saturation: S, brightness: B, alpha: 1.0)
    }
}

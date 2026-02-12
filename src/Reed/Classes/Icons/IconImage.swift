//
//  IconImage.swift
//  Reed
//
//  Created by Maurice Parker on 11/5/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import CoreGraphics
import UIKit

enum ImageLuminanceType: Sendable {
    case regular, bright, dark
}

final class IconImage: @unchecked Sendable {
    let image: UIImage
    let isSymbol: Bool
    let isBackgroundSuppressed: Bool
    let preferredColor: CGColor?

    private lazy var luminanceType: ImageLuminanceType = {
        guard let cgImage = image.cgImage else { return .regular }
        return cgImage.calculateLuminanceType() ?? .regular
    }()

    var isDark: Bool {
        self.luminanceType == .dark
    }

    var isBright: Bool {
        self.luminanceType == .bright
    }

    init(
        _ image: UIImage,
        isSymbol: Bool = false,
        isBackgroundSuppressed: Bool = false,
        preferredColor: CGColor? = nil
    ) {
        self.image = image
        self.isSymbol = isSymbol
        self.preferredColor = preferredColor
        self.isBackgroundSuppressed = isBackgroundSuppressed
    }
}

enum IconSize: Int, CaseIterable, Sendable {
    case small = 1
    case medium = 2
    case large = 3

    private static let smallDimension = CGFloat(integerLiteral: 24)
    private static let mediumDimension = CGFloat(integerLiteral: 36)
    private static let largeDimension = CGFloat(integerLiteral: 48)

    var size: CGSize {
        switch self {
        case .small:
            CGSize(width: IconSize.smallDimension, height: IconSize.smallDimension)
        case .medium:
            CGSize(width: IconSize.mediumDimension, height: IconSize.mediumDimension)
        case .large:
            CGSize(width: IconSize.largeDimension, height: IconSize.largeDimension)
        }
    }
}

// MARK: - CGImage Luminance Calculation

extension CGImage {
    func calculateLuminanceType() -> ImageLuminanceType? {
        let size = CGSize(width: 20, height: 20)
        let width = Int(size.width)
        let height = Int(size.height)
        let totalPixels = width * height

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo: UInt32 = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue

        guard
            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) else { return nil }

        context.draw(self, in: CGRect(origin: .zero, size: size))

        guard let pixelBuffer = context.data else { return nil }

        let pointer = pixelBuffer.bindMemory(to: UInt32.self, capacity: width * height)

        var totalLuminance = 0.0
        var pixelsProcessed = 0

        for i in 0..<totalPixels {
            let pixel = pointer[i]

            let r = UInt8((pixel >> 16) & 255)
            let g = UInt8((pixel >> 8) & 255)
            let b = UInt8((pixel >> 0) & 255)

            let luminance = (0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b))

            totalLuminance += luminance
            pixelsProcessed += 1

            if pixelsProcessed == totalPixels / 4 {
                let currentAvg = totalLuminance / Double(pixelsProcessed)
                if currentAvg < 30 {
                    return .dark
                } else if currentAvg > 190 {
                    return .bright
                }
            }
        }

        let avgLuminance = totalLuminance / Double(totalPixels)

        if totalLuminance == 0 || avgLuminance < 40 {
            return .dark
        } else if avgLuminance > 180 {
            return .bright
        } else {
            return .regular
        }
    }
}

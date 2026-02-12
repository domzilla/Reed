//
//  UIImage+Reed.swift
//  Reed
//
//  Created by Maurice Parker on 4/11/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import UIKit

typealias ImageResultBlock = @MainActor (UIImage?) -> Void

extension UIImage {
    static let maxIconSize = 48

    /// Create a colored image from the source image using a specified color.
    ///
    /// - Parameter color: The color with which to fill the mask image.
    /// - Returns: A new masked image.
    func maskWithColor(color: CGColor) -> UIImage? {
        guard let maskImage = cgImage else { return nil }

        let width = size.width
        let height = size.height
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        let context = CGContext(
            data: nil,
            width: Int(width),
            height: Int(height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        )!

        context.clip(to: bounds, mask: maskImage)
        context.setFillColor(color)
        context.fill(bounds)

        if let cgImage = context.makeImage() {
            let coloredImage = UIImage(cgImage: cgImage)
            return coloredImage
        } else {
            return nil
        }
    }

    /// Returns a data representation of the image.
    /// - Returns: Image data as PNG.
    func dataRepresentation() -> Data? {
        self.pngData()
    }

    /// Asynchronously initializes an image from data.
    ///
    /// - Parameters:
    ///   - data: The data object containing the image data.
    static func image(data: Data) async -> UIImage? {
        await withCheckedContinuation { continuation in
            UIImage.image(with: data) { image in
                continuation.resume(returning: image)
            }
        }
    }

    /// Asynchronously initializes an image from data.
    ///
    /// - Parameters:
    ///   - data: The data object containing the image data.
    ///   - imageResultBlock: The closure to call when the image has been initialized.
    static func image(with data: Data, imageResultBlock: @escaping ImageResultBlock) {
        DispatchQueue.global().async {
            let image = UIImage(data: data)
            DispatchQueue.main.async {
                imageResultBlock(image)
            }
        }
    }

    /// Create a scaled image from image data.
    ///
    /// - Note: the returned image may be larger than `maxPixelSize`, but not more than `maxPixelSize * 2`.
    /// - Parameters:
    ///   - data: The data object containing the image data.
    ///   - maxPixelSize: The maximum dimension of the image.
    static func scaleImage(_ data: Data, maxPixelSize: Int) -> CGImage? {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }

        let numberOfImages = CGImageSourceGetCount(imageSource)
        guard numberOfImages > 0 else {
            return nil
        }

        var exactMatch: (index: Int, maxDimension: Int)? = nil
        var goodMatch: (index: Int, maxDimension: Int)? = nil
        var smallMatch: (index: Int, maxDimension: Int)? = nil

        // Single pass through all images to find the best match
        for i in 0..<numberOfImages {
            guard
                let cfImageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, i, nil),
                let imagePixelWidth = (cfImageProperties as NSDictionary)[kCGImagePropertyPixelWidth] as? NSNumber,
                let imagePixelHeight = (cfImageProperties as NSDictionary)[kCGImagePropertyPixelHeight] as? NSNumber else {
                continue
            }

            let width = imagePixelWidth.intValue
            let height = imagePixelHeight.intValue
            let maxDimension = max(width, height)

            // Skip invalid dimensions
            guard width > 0, height > 0 else {
                continue
            }

            // Check for exact match (largest dimension equals maxPixelSize)
            if maxDimension == maxPixelSize {
                exactMatch = (i, maxDimension)
                break // Exact match is best, stop searching
            }

            // Check for good larger match
            if maxDimension > maxPixelSize, maxDimension <= maxPixelSize * 4 {
                if let currentGoodMatch = goodMatch {
                    if maxDimension < currentGoodMatch.maxDimension {
                        goodMatch = (i, maxDimension) // Prefer smaller size in this range
                    }
                } else {
                    goodMatch = (i, maxDimension)
                }
            }

            // Check for small match (smaller than maxPixelSize)
            if maxDimension < maxPixelSize {
                if let currentSmallMatch = smallMatch {
                    if maxDimension > currentSmallMatch.maxDimension {
                        smallMatch = (i, maxDimension) // Prefer larger size in this range
                    }
                } else {
                    smallMatch = (i, maxDimension)
                }
            }
        }

        // Return best match in order of preference: exact > good > small
        if let match = exactMatch ?? goodMatch ?? smallMatch {
            return CGImageSourceCreateImageAtIndex(imageSource, match.index, nil)
        }

        // Fallback to creating a thumbnail
        return UIImage.createThumbnail(imageSource, maxPixelSize: maxPixelSize)
    }

    /// Create a thumbnail from a CGImageSource.
    ///
    /// - Parameters:
    ///   - imageSource: The `CGImageSource` from which to create the thumbnail.
    ///   - maxPixelSize: The maximum dimension of the resulting image.
    static func createThumbnail(_ imageSource: CGImageSource, maxPixelSize: Int) -> CGImage? {
        guard maxPixelSize > 0 else {
            return nil
        }

        let count = CGImageSourceGetCount(imageSource)
        guard count > 0 else {
            return nil
        }

        let options = [
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceThumbnailMaxPixelSize: NSNumber(value: maxPixelSize),
        ]
        return CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary)
    }

    @MainActor
    static func scaledForIcon(_ data: Data, imageResultBlock: @escaping ImageResultBlock) {
        IconScalerQueue.shared.scaledForIcon(data, imageResultBlock)
    }

    nonisolated static func scaledForIcon(_ data: Data) -> UIImage? {
        let scaledMaxPixelSize = Int(ceil(CGFloat(UIImage.maxIconSize) * 3.0))
        guard let cgImage = UIImage.scaleImage(data, maxPixelSize: scaledMaxPixelSize) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}

// MARK: - IconScalerQueue

private final class IconScalerQueue: Sendable {
    static let shared = IconScalerQueue()

    private let queue: DispatchQueue = {
        let q = DispatchQueue(label: "IconScaler", attributes: .initiallyInactive)
        q.setTarget(queue: DispatchQueue.global(qos: .default))
        q.activate()
        return q
    }()

    func scaledForIcon(_ data: Data, _ imageResultBlock: @escaping ImageResultBlock) {
        self.queue.async {
            let image = UIImage.scaledForIcon(data)
            DispatchQueue.main.async {
                imageResultBlock(image)
            }
        }
    }
}

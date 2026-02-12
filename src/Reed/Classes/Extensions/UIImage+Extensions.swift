//
//  UIImage+Extensions.swift
//  RSCore
//
//  Created by Maurice Parker on 4/11/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

extension UIImage {
    static let maxIconSize = 48

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

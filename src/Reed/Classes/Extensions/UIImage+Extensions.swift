//
//  UIImage+Extensions.swift
//  RSCore
//
//  Created by Maurice Parker on 4/11/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import RSCore
import UIKit

extension UIImage {

	static let maxIconSize = 48

	static func scaledForIcon(_ data: Data, imageResultBlock: @escaping ImageResultBlock) {
		IconScalerQueue.shared.scaledForIcon(data, imageResultBlock)
	}

	static func scaledForIcon(_ data: Data) -> UIImage? {
		let scaledMaxPixelSize = Int(ceil(CGFloat(UIImage.maxIconSize) * RSScreen.maxScreenScale))
		guard let cgImage = UIImage.scaleImage(data, maxPixelSize: scaledMaxPixelSize) else {
			return nil
		}

		return UIImage(cgImage: cgImage)
	}

	static var appIconImage: UIImage? {
		// https://stackoverflow.com/a/51241158/14256
		if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
			let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
			let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
			let lastIcon = iconFiles.last {
			return UIImage(named: lastIcon)
		}
		return nil
	}
}

extension IconImage {
	static let appIcon: IconImage? = {
		if let image = UIImage.appIconImage {
			return IconImage(image)
		}
		return nil
	}()
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
		queue.async {
			let image = UIImage.scaledForIcon(data)
			DispatchQueue.main.async {
				imageResultBlock(image)
			}
		}
	}
}

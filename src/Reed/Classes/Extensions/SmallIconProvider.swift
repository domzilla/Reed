//
//  SmallIconProvider.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 12/16/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore

@MainActor protocol SmallIconProvider {
	var smallIcon: IconImage? { get }
}

@MainActor extension DataStore: SmallIconProvider {
	var smallIcon: IconImage? {
		// CloudKit icon represents sync capability
		let image = Assets.accountImage(.cloudKit)
		return IconImage(image)
	}
}

@MainActor extension Feed: SmallIconProvider {
	var smallIcon: IconImage? {
		if let iconImage = FaviconDownloader.shared.favicon(for: self) {
			return iconImage
		}
		return FaviconGenerator.favicon(self)
	}
}

@MainActor extension Folder: SmallIconProvider {
	var smallIcon: IconImage? {
		Assets.Images.mainFolder
	}
}

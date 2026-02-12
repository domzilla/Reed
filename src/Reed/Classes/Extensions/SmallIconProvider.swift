//
//  SmallIconProvider.swift
//  Reed
//
//  Created by Brent Simmons on 12/16/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation

@MainActor
protocol SmallIconProvider {
    var smallIcon: IconImage? { get }
}

@MainActor
extension DataStore: SmallIconProvider {
    var smallIcon: IconImage? {
        IconImage(Assets.Images.accountCloudKit)
    }
}

@MainActor
extension Feed: SmallIconProvider {
    private static var generatedFaviconCache = [String: IconImage]()

    var smallIcon: IconImage? {
        if let iconImage = FaviconDownloader.shared.favicon(for: self) {
            return iconImage
        }
        return self.generatedFavicon()
    }

    private func generatedFavicon() -> IconImage {
        if let cached = Feed.generatedFaviconCache[self.url] {
            return cached
        }

        let colorHash = ColorHash(self.url)
        if let favicon = Assets.Images.faviconTemplate.maskWithColor(color: colorHash.color.cgColor) {
            let iconImage = IconImage(favicon, isBackgroundSuppressed: true)
            Feed.generatedFaviconCache[self.url] = iconImage
            return iconImage
        } else {
            return IconImage(Assets.Images.faviconTemplate, isBackgroundSuppressed: true)
        }
    }
}

@MainActor
extension Folder: SmallIconProvider {
    var smallIcon: IconImage? {
        Assets.Images.mainFolder
    }
}

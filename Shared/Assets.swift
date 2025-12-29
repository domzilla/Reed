//
//  Assets.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/18/25.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import Foundation
import UIKit
import RSCore
import Account

typealias RSColor = UIColor

struct Assets {
	struct Images {
		static var accountCloudKit: RSImage { RSImage(named: "accountCloudKit")! }

		static var starOpen: RSImage { RSImage(symbol: "star")! }
		static var starClosed: RSImage { RSImage(symbol: "star.fill")! }
		static var copy: RSImage { RSImage(symbol: "document.on.document")! }
		static var markAllAsRead: RSImage { RSImage(named: "markAllAsRead")! }
		static var nextUnread: RSImage { RSImage(symbol: "chevron.down.circle")! }

		static var nnwFeedIcon: RSImage { RSImage(named: "nnwFeedIcon")! }
		static var faviconTemplate: RSImage { RSImage(named: "faviconTemplateImage")! }

		static var share: RSImage { RSImage(symbol: "square.and.arrow.up")! }
		static var folder: RSImage { RSImage(symbol: "folder")! }
		static var starredFeed: IconImage {
			IconImage(starClosed,
					  isSymbol: true,
					  isBackgroundSuppressed: true,
					  preferredColor: Assets.Colors.star.cgColor)
		}

		static var accountLocalPadImage: RSImage { RSImage(named: "accountLocalPad")! }
		static var accountLocalPhoneImage: RSImage { RSImage(named: "accountLocalPhone")! }

		static var circleClosed: RSImage { RSImage(symbol: "largecircle.fill.circle")! }
		static var markBelowAsRead: RSImage { RSImage(symbol: "arrowtriangle.down.circle")! }
		static var markAboveAsRead: RSImage { RSImage(symbol: "arrowtriangle.up.circle")! }
		static var more: RSImage { RSImage(symbol: "ellipsis.circle")! }
		static var nextArticle: RSImage { RSImage(symbol: "chevron.down")! }
		static var circleOpen: RSImage { RSImage(symbol: "circle")! }
		static var disclosure: RSImage { RSImage(named: "disclosure")! }
		static var deactivate: RSImage { RSImage(symbol: "minus.circle")! }
		static var edit: RSImage { RSImage(symbol: "square.and.pencil")! }
		static var filter: RSImage { RSImage(symbol: "line.3.horizontal.decrease")! }
		static var folderOutlinePlus: RSImage { RSImage(symbol: "folder.badge.plus")! }
		static var info: RSImage { RSImage(symbol: "info.circle")! }
		static var plus: RSImage { RSImage(symbol: "plus")! }
		static var prevArticle: RSImage { RSImage(symbol: "chevron.up")! }
		static var openInSidebar: RSImage { RSImage(symbol: "arrow.turn.down.left")! }
		static var safari: RSImage { RSImage(symbol: "safari")! }
		static var smartFeed: RSImage { RSImage(symbol: "gear")! }
		static var trash: RSImage { RSImage(symbol: "trash")! }

		static var searchFeed: IconImage {
			IconImage(RSImage(symbol: "magnifyingglass")!, isSymbol: true)
		}
		static var mainFolder: IconImage {
			IconImage(folder,
					  isSymbol: true,
					  isBackgroundSuppressed: true,
					  preferredColor: Assets.Colors.secondaryAccent.cgColor)
		}
		static var todayFeed: IconImage {
			let image = RSImage(symbol: "sun.max.fill")!
			return IconImage(image,
							 isSymbol: true,
							 isBackgroundSuppressed: true,
							 preferredColor: UIColor.systemOrange.cgColor)
		}
		static var unreadFeed: IconImage {
			let image = RSImage(symbol: "largecircle.fill.circle")!
			return IconImage(image,
							 isSymbol: true,
							 isBackgroundSuppressed: true,
							 preferredColor: Assets.Colors.secondaryAccent.cgColor)
		}
		static var timelineStar: RSImage {
			let image = RSImage(symbol: "star.fill")!
			return image.withTintColor(Assets.Colors.star, renderingMode: .alwaysOriginal)
		}
		static var unreadCellIndicator: IconImage {
			let image = RSImage(symbol: "circle.fill")!
			return IconImage(image,
							 isSymbol: true,
							 isBackgroundSuppressed: true,
							 preferredColor: Assets.Colors.secondaryAccent.cgColor)
		}
	}

	@MainActor static func accountImage(_ accountType: AccountType) -> RSImage {
		switch accountType {
		case .onMyMac:
			if UIDevice.current.userInterfaceIdiom == .pad {
				return Assets.Images.accountLocalPadImage
			} else {
				return Assets.Images.accountLocalPhoneImage
			}
		case .cloudKit:
			return Assets.Images.accountCloudKit
		}
	}

	struct Colors {
		static var primaryAccent: RSColor { RSColor(named: "primaryAccentColor")! }
		static var secondaryAccent: RSColor { RSColor(named: "secondaryAccentColor")! }
		static var star: RSColor { RSColor(named: "starColor")! }
		static var vibrantText: RSColor { RSColor(named: "vibrantTextColor")! }
		static var controlBackground: RSColor { RSColor(named: "controlBackgroundColor")! }
		static var iconBackground: RSColor { RSColor(named: "iconBackgroundColor")! }
		static var fullScreenBackground: RSColor { RSColor(named: "fullScreenBackgroundColor")! }
		static var sectionHeader: RSColor { RSColor(named: "sectionHeaderColor")! }
	}
}

extension RSImage {

	convenience init?(symbol: String) {
		self.init(systemName: symbol)
	}
}

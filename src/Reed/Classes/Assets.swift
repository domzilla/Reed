//
//  Assets.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/18/25.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore
import UIKit

enum Assets {
    enum Images {
        static var accountCloudKit: UIImage { UIImage(named: "accountCloudKit")! }

        static var starOpen: UIImage { UIImage(symbol: "star")! }
        static var starClosed: UIImage { UIImage(symbol: "star.fill")! }
        static var copy: UIImage { UIImage(symbol: "document.on.document")! }
        static var markAllAsRead: UIImage { UIImage(named: "markAllAsRead")! }
        static var nextUnread: UIImage { UIImage(symbol: "chevron.down.circle")! }

        static var faviconTemplate: UIImage { UIImage(named: "faviconTemplateImage")! }

        static var share: UIImage { UIImage(symbol: "square.and.arrow.up")! }
        static var folder: UIImage { UIImage(symbol: "folder")! }
        static var starredFeed: IconImage {
            IconImage(
                starClosed,
                isSymbol: true,
                isBackgroundSuppressed: true,
                preferredColor: Assets.Colors.star.cgColor
            )
        }

        static var accountLocalPadImage: UIImage { UIImage(named: "accountLocalPad")! }
        static var accountLocalPhoneImage: UIImage { UIImage(named: "accountLocalPhone")! }

        static var circleClosed: UIImage { UIImage(symbol: "largecircle.fill.circle")! }
        static var markBelowAsRead: UIImage { UIImage(symbol: "arrowtriangle.down.circle")! }
        static var markAboveAsRead: UIImage { UIImage(symbol: "arrowtriangle.up.circle")! }
        static var more: UIImage { UIImage(symbol: "ellipsis.circle")! }
        static var nextArticle: UIImage { UIImage(symbol: "chevron.down")! }
        static var circleOpen: UIImage { UIImage(symbol: "circle")! }
        static var disclosure: UIImage { UIImage(named: "disclosure")! }
        static var deactivate: UIImage { UIImage(symbol: "minus.circle")! }
        static var edit: UIImage { UIImage(symbol: "square.and.pencil")! }
        static var filter: UIImage { UIImage(symbol: "line.3.horizontal.decrease")! }
        static var folderOutlinePlus: UIImage { UIImage(symbol: "folder.badge.plus")! }
        static var info: UIImage { UIImage(symbol: "info.circle")! }
        static var plus: UIImage { UIImage(symbol: "plus")! }
        static var prevArticle: UIImage { UIImage(symbol: "chevron.up")! }
        static var openInSidebar: UIImage { UIImage(symbol: "arrow.turn.down.left")! }
        static var safari: UIImage { UIImage(symbol: "safari")! }
        static var smartFeed: UIImage { UIImage(symbol: "gear")! }
        static var trash: UIImage { UIImage(symbol: "trash")! }

        static var searchFeed: IconImage {
            IconImage(UIImage(symbol: "magnifyingglass")!, isSymbol: true)
        }

        static var mainFolder: IconImage {
            IconImage(
                folder,
                isSymbol: true,
                isBackgroundSuppressed: true,
                preferredColor: Assets.Colors.secondaryAccent.cgColor
            )
        }

        static var todayFeed: IconImage {
            let image = UIImage(symbol: "sun.max.fill")!
            return IconImage(
                image,
                isSymbol: true,
                isBackgroundSuppressed: true,
                preferredColor: UIColor.systemOrange.cgColor
            )
        }

        static var unreadFeed: IconImage {
            let image = UIImage(symbol: "largecircle.fill.circle")!
            return IconImage(
                image,
                isSymbol: true,
                isBackgroundSuppressed: true,
                preferredColor: Assets.Colors.secondaryAccent.cgColor
            )
        }

        static var timelineStar: UIImage {
            let image = UIImage(symbol: "star.fill")!
            return image.withTintColor(Assets.Colors.star, renderingMode: .alwaysOriginal)
        }

        static var unreadCellIndicator: IconImage {
            let image = UIImage(symbol: "circle.fill")!
            return IconImage(
                image,
                isSymbol: true,
                isBackgroundSuppressed: true,
                preferredColor: Assets.Colors.secondaryAccent.cgColor
            )
        }
    }

    @MainActor
    static func accountImage(_ accountType: AccountType) -> UIImage {
        switch accountType {
        case .onMyMac:
            if UIDevice.current.userInterfaceIdiom == .pad {
                Assets.Images.accountLocalPadImage
            } else {
                Assets.Images.accountLocalPhoneImage
            }
        case .cloudKit:
            Assets.Images.accountCloudKit
        }
    }

    enum Colors {
        static var primaryAccent: UIColor { UIColor(named: "primaryAccentColor")! }
        static var secondaryAccent: UIColor { UIColor(named: "secondaryAccentColor")! }
        static var star: UIColor { UIColor(named: "starColor")! }
        static var vibrantText: UIColor { UIColor(named: "vibrantTextColor")! }
        static var controlBackground: UIColor { UIColor(named: "controlBackgroundColor")! }
        static var iconBackground: UIColor { UIColor(named: "iconBackgroundColor")! }
        static var fullScreenBackground: UIColor { UIColor(named: "fullScreenBackgroundColor")! }
        static var sectionHeader: UIColor { UIColor(named: "sectionHeaderColor")! }
    }
}

extension UIImage {
    convenience init?(symbol: String) {
        self.init(systemName: symbol)
    }
}

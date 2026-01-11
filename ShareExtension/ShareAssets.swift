//
//  ShareAssets.swift
//  NetNewsWire iOS Share Extension
//
//  Minimal Assets subset for the Share Extension.
//

import UIKit

/// Provides account and folder images for the Share Extension UI.
enum ShareAssets {
	struct Images {
		/// Folder icon image.
		static var mainFolder: ShareIconImage {
			ShareIconImage(UIImage(systemName: "folder.fill")!)
		}
	}

	/// Returns the appropriate image for an account type.
	@MainActor static func accountImage(_ accountType: AccountType) -> UIImage {
		switch accountType {
		case .onMyMac:
			if UIDevice.current.userInterfaceIdiom == .pad {
				return UIImage(systemName: "desktopcomputer")!
			} else {
				return UIImage(systemName: "iphone")!
			}
		case .cloudKit:
			return UIImage(systemName: "icloud")!
		}
	}
}

/// Simplified icon wrapper for ShareExtension (RSCore's IconImage is not available).
struct ShareIconImage {
	let image: UIImage

	init(_ image: UIImage) {
		self.image = image
	}
}

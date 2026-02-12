//
//  ShareAssets.swift
//  Reed
//
//  Minimal Assets subset for the Share Extension.
//

import UIKit

/// Provides account and folder images for the Share Extension UI.
enum ShareAssets {
    enum Images {
        /// Folder icon image.
        static var mainFolder: ShareIconImage {
            ShareIconImage(UIImage(systemName: "folder.fill")!)
        }
    }

    /// Returns the appropriate image for a data store type.
    @MainActor
    static func dataStoreImage(_ dataStoreType: DataStoreType) -> UIImage {
        switch dataStoreType {
        case .onMyMac:
            if UIDevice.current.userInterfaceIdiom == .pad {
                UIImage(systemName: "desktopcomputer")!
            } else {
                UIImage(systemName: "iphone")!
            }
        case .cloudKit:
            UIImage(systemName: "icloud")!
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

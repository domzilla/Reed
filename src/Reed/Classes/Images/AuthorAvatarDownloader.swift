//
//  AuthorAvatarDownloader.swift
//  Reed
//
//  Created by Brent Simmons on 11/26/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore

extension Notification.Name {
    static let AvatarDidBecomeAvailable = Notification
        .Name("AvatarDidBecomeAvailableNotification") // UserInfoKey.imageURL (which is an avatarURL)
}

@MainActor
final class AuthorAvatarDownloader {
    static let shared = AuthorAvatarDownloader()

    private let imageDownloader = ImageDownloader.shared
    private var cache = [String: IconImage]() // avatarURL: UIImage
    private var waitingForAvatarURLs = Set<String>()

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.imageDidBecomeAvailable(_:)),
            name: .imageDidBecomeAvailable,
            object: self.imageDownloader
        )
    }

    func resetCache() {
        self.cache = [String: IconImage]()
    }

    func image(for author: Author) -> IconImage? {
        guard let avatarURL = author.avatarURL else {
            return nil
        }

        if let cachedImage = cache[avatarURL] {
            return cachedImage
        }

        if let imageData = imageDownloader.image(for: avatarURL) {
            scaleAndCacheImageData(imageData, avatarURL)
        } else {
            self.waitingForAvatarURLs.insert(avatarURL)
        }

        return nil
    }

    @objc
    func imageDidBecomeAvailable(_ note: Notification) {
        guard let avatarURL = note.userInfo?[UserInfoKey.url] as? String else {
            return
        }
        guard self.waitingForAvatarURLs.contains(avatarURL) else {
            return
        }
        guard let imageData = imageDownloader.image(for: avatarURL) else {
            return
        }
        scaleAndCacheImageData(imageData, avatarURL)
    }
}

@MainActor
extension AuthorAvatarDownloader {
    private func scaleAndCacheImageData(_ imageData: Data, _ avatarURL: String) {
        UIImage.scaledForIcon(imageData) { image in
            MainActor.assumeIsolated {
                if let image {
                    self.handleImageDidBecomeAvailable(avatarURL, image)
                }
            }
        }
    }

    private func handleImageDidBecomeAvailable(_ avatarURL: String, _ image: UIImage) {
        if self.cache[avatarURL] == nil {
            self.cache[avatarURL] = IconImage(image)
        }
        if self.waitingForAvatarURLs.contains(avatarURL) {
            self.waitingForAvatarURLs.remove(avatarURL)
            self.postAvatarDidBecomeAvailableNotification(avatarURL)
        }
    }

    private func postAvatarDidBecomeAvailableNotification(_ avatarURL: String) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .AvatarDidBecomeAvailable,
                object: self,
                userInfo: [UserInfoKey.url: avatarURL]
            )
        }
    }
}

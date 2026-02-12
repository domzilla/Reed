//
//  ImageDownloader.swift
//  Reed
//
//  Created by Brent Simmons on 11/25/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import DZFoundation
import Foundation

extension Notification.Name {
    static let imageDidBecomeAvailable = Notification.Name("ImageDidBecomeAvailableNotification") // UserInfoKey.url
    static let avatarDidBecomeAvailable = Notification.Name("AvatarDidBecomeAvailableNotification") // UserInfoKey.url
}

@MainActor
final class ImageDownloader {
    static let shared = ImageDownloader()

    private nonisolated let diskCache: BinaryDiskCache
    private let queue: DispatchQueue
    private var imageCache = [String: Data]() // url: image
    private var urlsInProgress = Set<String>()
    private var badURLs = Set<String>() // That return a 404 or whatever. Just skip them in the future.

    // MARK: Avatar Support

    private var avatarCache = [String: IconImage]() // avatarURL: IconImage
    private var waitingForAvatarURLs = Set<String>()

    init() {
        let folder = AppConfig.cacheSubfolder(named: "Images")
        self.diskCache = BinaryDiskCache(folder: folder.path)
        self.queue = DispatchQueue(label: "ImageDownloader serial queue - \(folder.path)")
    }

    @discardableResult
    func image(for url: String) -> Data? {
        assert(Thread.isMainThread)
        if let data = imageCache[url] {
            return data
        }

        Task { @MainActor in
            await findImage(url)
        }

        return nil
    }

    func avatarImage(for author: Author) -> IconImage? {
        guard let avatarURL = author.avatarURL else {
            return nil
        }

        if let cachedImage = avatarCache[avatarURL] {
            return cachedImage
        }

        if let imageData = image(for: avatarURL) {
            self.scaleAndCacheAvatar(imageData, avatarURL)
        } else {
            self.waitingForAvatarURLs.insert(avatarURL)
        }

        return nil
    }
}

extension ImageDownloader {
    private func cacheImage(_ url: String, _ image: Data) {
        assert(Thread.isMainThread)
        self.imageCache[url] = image
        self.postImageDidBecomeAvailableNotification(url)
        self.processAvatarIfNeeded(url, image)
    }

    private func findImage(_ url: String) async {
        guard !self.urlsInProgress.contains(url), !self.badURLs.contains(url) else {
            return
        }
        self.urlsInProgress.insert(url)

        if let image = await readFromDisk(url: url) {
            self.cacheImage(url, image)
            self.urlsInProgress.remove(url)
            return
        }

        if let image = await downloadImage(url) {
            self.cacheImage(url, image)
            self.urlsInProgress.remove(url)
        }
    }

    private func readFromDisk(url: String) async -> Data? {
        await withCheckedContinuation { continuation in
            self.readFromDisk(url) { data in
                continuation.resume(returning: data)
            }
        }
    }

    private func readFromDisk(_ url: String, _ completion: @escaping @MainActor (Data?) -> Void) {
        self.queue.async {
            if let data = self.diskCache[self.diskKey(url)], !data.isEmpty {
                DispatchQueue.main.async {
                    completion(data)
                }
                return
            }

            DispatchQueue.main.async {
                completion(nil)
            }
        }
    }

    private func downloadImage(_ url: String) async -> Data? {
        guard let imageURL = URL(string: url) else {
            return nil
        }

        do {
            let (data, response) = try await Downloader.shared.download(imageURL)

            if let data, !data.isEmpty, let response, response.statusIsOK {
                self.saveToDisk(url, data)
                return data
            }

            if
                let response = response as? HTTPURLResponse, response.statusCode >= HTTPResponseCode.badRequest,
                response.statusCode <= HTTPResponseCode.notAcceptable
            {
                self.badURLs.insert(url)
            }

            return nil
        } catch {
            DZLog("Error downloading image at \(url) \(error.localizedDescription)")
            return nil
        }
    }

    private func saveToDisk(_ url: String, _ data: Data) {
        self.queue.async {
            self.diskCache[self.diskKey(url)] = data
        }
    }

    private nonisolated func diskKey(_ url: String) -> String {
        url.md5String
    }

    private func postImageDidBecomeAvailableNotification(_ url: String) {
        assert(Thread.isMainThread)
        NotificationCenter.default.post(name: .imageDidBecomeAvailable, object: self, userInfo: [UserInfoKey.url: url])
    }

    // MARK: Avatar Support

    private func processAvatarIfNeeded(_ url: String, _ imageData: Data) {
        guard self.waitingForAvatarURLs.contains(url) else {
            return
        }
        self.scaleAndCacheAvatar(imageData, url)
    }

    private func scaleAndCacheAvatar(_ imageData: Data, _ avatarURL: String) {
        UIImage.scaledForIcon(imageData) { image in
            MainActor.assumeIsolated {
                if let image {
                    self.handleAvatarDidBecomeAvailable(avatarURL, image)
                }
            }
        }
    }

    private func handleAvatarDidBecomeAvailable(_ avatarURL: String, _ image: UIImage) {
        if self.avatarCache[avatarURL] == nil {
            self.avatarCache[avatarURL] = IconImage(image)
        }
        if self.waitingForAvatarURLs.contains(avatarURL) {
            self.waitingForAvatarURLs.remove(avatarURL)
            self.postAvatarDidBecomeAvailableNotification(avatarURL)
        }
    }

    private func postAvatarDidBecomeAvailableNotification(_ avatarURL: String) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .avatarDidBecomeAvailable,
                object: self,
                userInfo: [UserInfoKey.url: avatarURL]
            )
        }
    }
}

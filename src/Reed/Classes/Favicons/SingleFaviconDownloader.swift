//
//  SingleFaviconDownloader.swift
//  Reed
//
//  Created by Brent Simmons on 11/23/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import DZFoundation
import Foundation
import RSCore
import RSWeb

// The image may be on disk already. If not, download it.
// Post .DidLoadFavicon notification once it's in memory.

extension Notification.Name {
    static let DidLoadFavicon = Notification.Name("DidLoadFaviconNotification")
}

@MainActor
final class SingleFaviconDownloader {
    private enum DiskStatus {
        case unknown, notOnDisk, onDisk
    }

    let faviconURL: String
    let homePageURL: String?

    var iconImage: IconImage?

    private let diskCache: BinaryDiskCache
    private let queue: DispatchQueue
    private let diskKey: String

    private var lastDownloadAttemptDate: Date
    private var diskStatus = DiskStatus.unknown

    init(faviconURL: String, homePageURL: String?, diskCache: BinaryDiskCache, queue: DispatchQueue) {
        self.faviconURL = faviconURL
        self.homePageURL = homePageURL
        self.diskCache = diskCache
        self.queue = queue
        self.lastDownloadAttemptDate = Date()
        self.diskKey = faviconURL.md5String

        Task { @MainActor in
            await findFavicon()
        }
    }

    func downloadFaviconIfNeeded() -> Bool {
        // If we don’t have an image, and lastDownloadAttemptDate is a while ago, try again.
        guard self.iconImage == nil else {
            return false
        }

        let retryInterval: TimeInterval = 30 * 60 // 30 minutes
        if Date().timeIntervalSince(self.lastDownloadAttemptDate) < retryInterval {
            return false
        }
        self.lastDownloadAttemptDate = Date()

        Task { @MainActor in
            await findFavicon()
        }

        return true
    }
}

extension SingleFaviconDownloader {
    private func findFavicon() async {
        if let image = await readFromDisk() {
            self.diskStatus = .onDisk
            self.iconImage = IconImage(image)
            self.postDidLoadFaviconNotification()
            return
        }

        self.diskStatus = .notOnDisk

        if let image = await downloadFavicon() {
            self.iconImage = IconImage(image)
            self.postDidLoadFaviconNotification()
        }
    }

    private func readFromDisk() async -> UIImage? {
        await withCheckedContinuation { continuation in
            self.readFromDisk { image in
                continuation.resume(returning: image)
            }
        }
    }

    private func readFromDisk(_ completion: @escaping @MainActor (UIImage?) -> Void) {
        guard self.diskStatus != .notOnDisk else {
            completion(nil)
            return
        }

        self.queue.async {
            if let data = self.diskCache[self.diskKey], !data.isEmpty {
                UIImage.image(with: data, imageResultBlock: completion)
                return
            }

            Task { @MainActor in
                completion(nil)
            }
        }
    }

    private func saveToDisk(_ data: Data) {
        self.queue.async {
            do {
                try self.diskCache.setData(data, forKey: self.diskKey)
                Task { @MainActor in
                    self.diskStatus = .onDisk
                }
            } catch {}
        }
    }

    private func downloadFavicon() async -> UIImage? {
        assert(Thread.isMainThread)

        guard let url = URL(string: faviconURL) else {
            return nil
        }

        do {
            let (data, response) = try await Downloader.shared.download(url)
            if let data, !data.isEmpty, let response, response.statusIsOK {
                self.saveToDisk(data)
                let image = await UIImage.image(data: data)
                return image
            }

        } catch {
            DZLog("Error downloading image at \(url.absoluteString): \(error.localizedDescription)")
        }

        return nil
    }

    private func postDidLoadFaviconNotification() {
        assert(Thread.isMainThread)
        NotificationCenter.default.post(name: .DidLoadFavicon, object: self)
    }
}

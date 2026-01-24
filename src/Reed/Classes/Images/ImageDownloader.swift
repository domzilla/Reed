//
//  ImageDownloader.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/25/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import os.log
import RSCore
import RSWeb

extension Notification.Name {
    static let imageDidBecomeAvailable = Notification.Name("ImageDidBecomeAvailableNotification") // UserInfoKey.url
}

@MainActor
final class ImageDownloader {
    static let shared = ImageDownloader()

    private nonisolated static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: "ImageDownloader"
    )

    private nonisolated let diskCache: BinaryDiskCache
    private let queue: DispatchQueue
    private var imageCache = [String: Data]() // url: image
    private var urlsInProgress = Set<String>()
    private var badURLs = Set<String>() // That return a 404 or whatever. Just skip them in the future.

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
}

extension ImageDownloader {
    private func cacheImage(_ url: String, _ image: Data) {
        assert(Thread.isMainThread)
        self.imageCache[url] = image
        self.postImageDidBecomeAvailableNotification(url)
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
            Self.logger.error("Error downloading image at \(url) \(error.localizedDescription)")
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
}

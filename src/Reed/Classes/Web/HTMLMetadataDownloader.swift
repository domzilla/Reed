//
//  HTMLMetadataDownloader.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/26/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import DZFoundation
import Foundation
import os

// To get a notification when HTMLMetadata is cached, see HTMLMetadataCache.

final nonisolated class HTMLMetadataDownloader: Sendable {
    static let shared = HTMLMetadataDownloader()

    private let cache = HTMLMetadataCache()
    private let attemptDatesLock = OSAllocatedUnfairLock(initialState: [String: Date]())
    private let urlsReturning4xxsLock = OSAllocatedUnfairLock(initialState: Set<String>())

    func cachedMetadata(for url: String) -> RDHTMLMetadata? {
        if Self.shouldSkipDownloadingMetadata(url) {
            DZLog("HTMLMetadataDownloader: Skipping requested cached metadata for \(url)")
            return nil
        }

        DZLog("HTMLMetadataDownloader requested cached metadata for \(url)")

        guard let htmlMetadata = cache[url] else {
            downloadMetadataIfNeeded(url)
            return nil
        }

        DZLog("HTMLMetadataDownloader returning cached metadata for \(url)")
        return htmlMetadata
    }
}

nonisolated extension HTMLMetadataDownloader {
    private static let specialCasesToSkip = [SpecialCase.rachelByTheBayHostName, SpecialCase.openRSSOrgHostName]

    fileprivate static func shouldSkipDownloadingMetadata(_ urlString: String) -> Bool {
        SpecialCase.urlStringContainSpecialCase(urlString, self.specialCasesToSkip)
    }

    private func downloadMetadataIfNeeded(_ url: String) {
        if self.urlShouldBeSkippedDueToPrevious4xxResponse(url) {
            DZLog(
                "HTMLMetadataDownloader skipping download for \(url) because an earlier request returned a 4xx response."
            )
            return
        }

        // Limit how often a download should be attempted.
        let shouldDownload = self.attemptDatesLock.withLock { attemptDates in
            let currentDate = Date()

            let hoursBetweenAttempts = 3 // arbitrary
            if
                let attemptDate = attemptDates[url],
                attemptDate > currentDate.bySubtracting(hours: hoursBetweenAttempts)
            {
                DZLog(
                    "HTMLMetadataDownloader skipping download for \(url) because an attempt was made less than an hour ago."
                )
                return false
            }

            attemptDates[url] = currentDate
            return true
        }

        if shouldDownload {
            self.downloadMetadata(url)
        }
    }

    private func downloadMetadata(_ url: String) {
        guard let actualURL = URL(string: url) else {
            DZLog("HTMLMetadataDownloader skipping download for \(url) because it couldn’t construct a URL.")
            return
        }

        DZLog("HTMLMetadataDownloader downloading for \(url)")

        Task { @MainActor in
            do {
                let (data, response) = try await Downloader.shared.download(actualURL)

                if let data, !data.isEmpty, let response, response.statusIsOK {
                    let urlToUse = response.url ?? actualURL
                    let parserData = ParserData(url: urlToUse.absoluteString, data: data)
                    let htmlMetadata = RDHTMLMetadataParser.htmlMetadata(with: parserData)
                    DZLog("HTMLMetadataDownloader caching parsed metadata for \(url)")
                    self.cache[url] = htmlMetadata
                    return
                }

                let statusCode = response?.forcedStatusCode ?? -1
                if (400...499).contains(statusCode) {
                    self.noteURLDidReturn4xx(url)
                }

                DZLog("HTMLMetadataDownloader failed download for \(url) statusCode: \(statusCode)")
            } catch {
                DZLog("HTMLMetadataDownloader failed download for \(url) error: \(error.localizedDescription)")
            }
        }
    }

    private func urlShouldBeSkippedDueToPrevious4xxResponse(_ url: String) -> Bool {
        self.urlsReturning4xxsLock.withLock { $0.contains(url) }
    }

    private func noteURLDidReturn4xx(_ url: String) {
        _ = self.urlsReturning4xxsLock.withLock { $0.insert(url) }
    }
}

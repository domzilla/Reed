//
//  WidgetDataEncoder.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 18/11/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import DZFoundation
import Foundation
import RSCore
import UIKit
import WidgetKit

@MainActor
final class WidgetDataEncoder {
    static let shared = WidgetDataEncoder()

    var isRunning = false

    private let fetchLimit = 7
    private let imageContainer: URL
    private let dataURL: URL

    init?() {
        guard
            let containerURL = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: AppConstants.appGroup) else
        {
            DZLog("WidgetDataEncoder: unable to create containerURL")
            return nil
        }

        self.imageContainer = containerURL.appendingPathComponent("widgetImages", isDirectory: true)
        self.dataURL = containerURL.appendingPathComponent("widget-data.json")

        do {
            try FileManager.default.createDirectory(
                at: self.imageContainer,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            DZLog("WidgetDataEncoder: unable to create folder for images")
            return nil
        }
    }

    func encode() {
        if self.isRunning {
            DZLog("WidgetDataEncoder: skipping encode because already in encode")
            return
        }

        DZLog("WidgetDataEncoder: encoding")
        self.isRunning = true

        flushSharedContainer()

        Task { @MainActor in
            defer {
                isRunning = false
            }

            let latestData: WidgetData
            do {
                latestData = try await fetchWidgetData()
            } catch {
                DZLog("WidgetDataEncoder: error fetching widget data: \(error.localizedDescription)")
                return
            }

            let encodedData: Data
            do {
                encodedData = try JSONEncoder().encode(latestData)
            } catch {
                DZLog("WidgetDataEncoder: error encoding widget data: \(error.localizedDescription)")
                return
            }

            if fileExists() {
                try? FileManager.default.removeItem(at: self.dataURL)
                DZLog("WidgetDataEncoder: removed widget data from container")
            }

            if FileManager.default.createFile(atPath: self.dataURL.path, contents: encodedData, attributes: nil) {
                DZLog("WidgetDataEncoder: wrote data to container")
                WidgetCenter.shared.reloadAllTimelines()
            } else {
                DZLog("WidgetDataEncoder: could not write data to container")
            }
        }
    }
}

@MainActor
extension WidgetDataEncoder {
    private func fetchWidgetData() async throws -> WidgetData {
        let fetchedUnreadArticles = try await AccountManager.shared.fetchArticlesAsync(.unread(self.fetchLimit))
        let unreadArticles = self.sortedLatestArticles(fetchedUnreadArticles)

        let fetchedStarredArticles = try await AccountManager.shared.fetchArticlesAsync(.starred(self.fetchLimit))
        let starredArticles = self.sortedLatestArticles(fetchedStarredArticles)

        let fetchedTodayArticles = try await AccountManager.shared.fetchArticlesAsync(.today(self.fetchLimit))
        let todayArticles = self.sortedLatestArticles(fetchedTodayArticles)

        let latestData = WidgetData(
            currentUnreadCount: SmartFeedsController.shared.unreadFeed.unreadCount,
            currentTodayCount: SmartFeedsController.shared.todayFeed.unreadCount,
            currentStarredCount: (try? AccountManager.shared.fetchCountForStarredArticles()) ??
                0,
            unreadArticles: unreadArticles,
            starredArticles: starredArticles,
            todayArticles: todayArticles,
            lastUpdateTime: Date()
        )
        return latestData
    }

    private func fileExists() -> Bool {
        FileManager.default.fileExists(atPath: self.dataURL.path)
    }

    private func writeImageDataToSharedContainer(_ imageData: Data?) -> String? {
        guard let imageData else {
            return nil
        }

        // Each image gets a UUID
        let uuid = UUID().uuidString

        let imagePath = self.imageContainer.appendingPathComponent(uuid, isDirectory: false)
        do {
            try imageData.write(to: imagePath)
            return imagePath.path
        } catch {
            return nil
        }
    }

    private func flushSharedContainer() {
        try? FileManager.default.removeItem(atPath: self.imageContainer.path)
        try? FileManager.default.createDirectory(
            at: self.imageContainer,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    private func createLatestArticle(_ article: Article) -> LatestArticle {
        let truncatedTitle = ArticleStringFormatter.truncatedTitle(article)
        let articleTitle = truncatedTitle.isEmpty ? ArticleStringFormatter.truncatedSummary(article) : truncatedTitle

        // TODO: It looks like we write images each time, but we’re probably over-writing unchanged images sometimes.
        let feedIconPath = self.writeImageDataToSharedContainer(article.iconImage()?.image.dataRepresentation())

        let pubDate = article.datePublished?.description ?? ""

        let latestArticle = LatestArticle(
            id: article.sortableArticleID,
            feedTitle: article.sortableName,
            articleTitle: articleTitle,
            articleSummary: article.summary,
            feedIconPath: feedIconPath,
            pubDate: pubDate
        )
        return latestArticle
    }

    private func sortedLatestArticles(_ fetchedArticles: Set<Article>) -> [LatestArticle] {
        let latestArticles = fetchedArticles.map(self.createLatestArticle)
        return latestArticles.sorted(by: { $0.pubDate > $1.pubDate })
    }
}

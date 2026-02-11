//
//  WidgetDataDecoder.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 18/11/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation

enum WidgetDataDecoder {
    static func decodeWidgetData() throws -> WidgetData {
        let containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppConstants.appGroup)
        let dataURL = containerURL?.appendingPathComponent("widget-data.json")
        if FileManager.default.fileExists(atPath: dataURL!.path) {
            let decodedWidgetData = try JSONDecoder().decode(WidgetData.self, from: Data(contentsOf: dataURL!))
            return decodedWidgetData
        } else {
            return WidgetData(
                currentUnreadCount: 0,
                currentTodayCount: 0,
                currentStarredCount: 0,
                unreadArticles: [],
                starredArticles: [],
                todayArticles: [],
                lastUpdateTime: Date()
            )
        }
    }

    static func sampleData() -> WidgetData {
        let pathToSample = Bundle.main.url(forResource: "widget-sample", withExtension: "json")
        do {
            let data = try Data(contentsOf: pathToSample!)
            let decoded = try JSONDecoder().decode(WidgetData.self, from: data)
            return decoded
        } catch {
            return WidgetData(
                currentUnreadCount: 0,
                currentTodayCount: 0,
                currentStarredCount: 0,
                unreadArticles: [],
                starredArticles: [],
                todayArticles: [],
                lastUpdateTime: Date()
            )
        }
    }
}

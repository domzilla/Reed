//
//  WebViewProvider.swift
//  Reed
//
//  Created by Maurice Parker on 9/21/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import WebKit

/// WKWebView has an awful behavior of a flash to white on first load when in dark mode.
/// Keep a queue of WebViews where we've already done a trivial load so that by the time we need them in the UI, they're
/// past the flash-to-white part of their lifecycle.
@MainActor
final class WebViewProvider {
    private let minimumQueueDepth = 3
    private let articleIconSchemeHandler: ArticleIconSchemeHandler
    private var queue = [PreloadedWebView]()

    init(coordinator: SceneCoordinator) {
        self.articleIconSchemeHandler = ArticleIconSchemeHandler(coordinator: coordinator)
        self.replenishQueueIfNeeded()
    }

    func replenishQueueIfNeeded() {
        while self.queue.count < self.minimumQueueDepth {
            let webView = PreloadedWebView(articleIconSchemeHandler: self.articleIconSchemeHandler)
            webView.preload()
            self.queue.insert(webView, at: 0)
        }
    }

    func dequeueWebView(completion: @escaping (PreloadedWebView) -> Void) {
        if let webView = self.queue.last {
            completion(webView)
            self.queue.removeLast()
        } else {
            assertionFailure("Creating PreloadedWebView in \(#function); queue has run dry.")
            let webView = PreloadedWebView(articleIconSchemeHandler: self.articleIconSchemeHandler)
            webView.preload()
            completion(webView)
        }
        self.replenishQueueIfNeeded()
    }
}

//
//  WebViewProvider.swift
//  Reed
//
//  Created by Maurice Parker on 9/21/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore
import WebKit

/// WKWebView has an awful behavior of a flash to white on first load when in dark mode.
/// Keep a queue of WebViews where we've already done a trivial load so that by the time we need them in the UI, they're
/// past the flash-to-white part of their lifecycle.
@MainActor
final class WebViewProvider: NSObject {
    private let articleIconSchemeHandler: ArticleIconSchemeHandler
    private let operationQueue = MainThreadOperationQueue()
    private var queue = NSMutableArray()

    init(coordinator: SceneCoordinator) {
        self.articleIconSchemeHandler = ArticleIconSchemeHandler(coordinator: coordinator)
        super.init()
        self.replenishQueueIfNeeded()
    }

    func replenishQueueIfNeeded() {
        self.operationQueue.add(WebViewProviderReplenishQueueOperation(
            queue: self.queue,
            articleIconSchemeHandler: self.articleIconSchemeHandler
        ))
    }

    func dequeueWebView(completion: @escaping (PreloadedWebView) -> Void) {
        self.operationQueue.add(WebViewProviderDequeueOperation(
            queue: self.queue,
            articleIconSchemeHandler: self.articleIconSchemeHandler,
            completion: completion
        ))
        self.operationQueue.add(WebViewProviderReplenishQueueOperation(
            queue: self.queue,
            articleIconSchemeHandler: self.articleIconSchemeHandler
        ))
    }
}

final class WebViewProviderReplenishQueueOperation: MainThreadOperation, @unchecked Sendable {
    private let minimumQueueDepth = 3

    private var queue: NSMutableArray
    private var articleIconSchemeHandler: ArticleIconSchemeHandler

    init(queue: NSMutableArray, articleIconSchemeHandler: ArticleIconSchemeHandler) {
        self.queue = queue
        self.articleIconSchemeHandler = articleIconSchemeHandler
        super.init(name: "WebViewProviderReplenishQueueOperation")
    }

    override func run() {
        while self.queue.count < self.minimumQueueDepth {
            let webView = PreloadedWebView(articleIconSchemeHandler: articleIconSchemeHandler)
            webView.preload()
            self.queue.insert(webView, at: 0)
        }
        didComplete()
    }
}

final class WebViewProviderDequeueOperation: MainThreadOperation, @unchecked Sendable {
    private var queue: NSMutableArray
    private var articleIconSchemeHandler: ArticleIconSchemeHandler
    private var completion: (PreloadedWebView) -> Void

    init(
        queue: NSMutableArray,
        articleIconSchemeHandler: ArticleIconSchemeHandler,
        completion: @escaping (PreloadedWebView) -> Void
    ) {
        self.queue = queue
        self.articleIconSchemeHandler = articleIconSchemeHandler
        self.completion = completion
        super.init(name: "WebViewProviderFlushQueueOperation")
    }

    override func run() {
        if let webView = queue.lastObject as? PreloadedWebView {
            self.completion(webView)
            self.queue.remove(webView)
            didComplete()
            return
        }

        assertionFailure("Creating PreloadedWebView in \(#function); queue has run dry.")

        let webView = PreloadedWebView(articleIconSchemeHandler: articleIconSchemeHandler)
        webView.preload()
        self.completion(webView)
        didComplete()
    }
}

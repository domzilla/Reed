//
//  PreloadedWebView.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 2/25/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import WebKit

final class PreloadedWebView: WKWebView {
    private var isReady: Bool = false
    private var readyCompletion: (() -> Void)?

    init(articleIconSchemeHandler: ArticleIconSchemeHandler) {
        let configuration = WebViewConfiguration.configuration(with: articleIconSchemeHandler)
        super.init(frame: .zero, configuration: configuration)
        NotificationCenter.default
            .addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.userDefaultsDidChange()
                }
            }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    func preload() {
        navigationDelegate = self
        loadFileURL(ArticleRenderer.blank.url, allowingReadAccessTo: ArticleRenderer.blank.baseURL)
    }

    func ready(completion: @escaping () -> Void) {
        if self.isReady {
            completeRequest(completion: completion)
        } else {
            self.readyCompletion = completion
        }
    }

    func userDefaultsDidChange() {
        if
            configuration.defaultWebpagePreferences.allowsContentJavaScript != AppDefaults.shared
                .isArticleContentJavascriptEnabled
        {
            configuration.defaultWebpagePreferences.allowsContentJavaScript = AppDefaults.shared
                .isArticleContentJavascriptEnabled
            reload()
        }
    }
}

// MARK: WKScriptMessageHandler

extension PreloadedWebView: WKNavigationDelegate {
    func webView(_: WKWebView, didFinish _: WKNavigation!) {
        self.isReady = true
        if let completion = readyCompletion {
            completeRequest(completion: completion)
            self.readyCompletion = nil
        }
    }
}

// MARK: Private

extension PreloadedWebView {
    private func completeRequest(completion: @escaping () -> Void) {
        self.isReady = false
        navigationDelegate = nil
        completion()
    }
}

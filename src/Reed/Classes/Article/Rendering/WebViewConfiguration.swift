//
//  WebViewConfiguration.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 1/15/25.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import Foundation
import WebKit

@MainActor
final class WebViewConfiguration {
    static func configuration(with urlSchemeHandler: WKURLSchemeHandler) -> WKWebViewConfiguration {
        assert(Thread.isMainThread)

        let configuration = WKWebViewConfiguration()

        configuration.preferences = preferences
        configuration.defaultWebpagePreferences = webpagePreferences
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        configuration.setURLSchemeHandler(urlSchemeHandler, forURLScheme: ArticleRenderer.imageIconScheme)
        configuration.userContentController = userContentController
        configuration.allowsInlineMediaPlayback = true

        return configuration
    }
}

extension WebViewConfiguration {
    fileprivate static var preferences: WKPreferences {
        let preferences = WKPreferences()
        preferences.javaScriptCanOpenWindowsAutomatically = false
        preferences.minimumFontSize = 12
        preferences.isElementFullscreenEnabled = true

        return preferences
    }

    fileprivate static var webpagePreferences: WKWebpagePreferences {
        assert(Thread.isMainThread)

        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = AppDefaults.shared.isArticleContentJavascriptEnabled
        return preferences
    }

    fileprivate static var userContentController: WKUserContentController {
        let userContentController = WKUserContentController()
        for script in articleScripts {
            userContentController.addUserScript(script)
        }
        return userContentController
    }

    fileprivate static let articleScripts: [WKUserScript] = {
        let filenames = ["main", "main_ios", "newsfoot"]

        let scripts = filenames.map { filename in
            let scriptURL = Bundle.main.url(forResource: filename, withExtension: ".js")!
            let scriptSource = try! String(contentsOf: scriptURL, encoding: .utf8)
            return WKUserScript(source: scriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        }
        return scripts
    }()
}

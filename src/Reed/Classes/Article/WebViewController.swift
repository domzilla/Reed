//
//  WebViewController.swift
//  Reed
//
//  Created by Maurice Parker on 12/28/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import SafariServices
import UIKit
@preconcurrency import WebKit

final class WebViewController: UIViewController {
    private enum MessageName {
        static let imageWasClicked = "imageWasClicked"
        static let imageWasShown = "imageWasShown"
        static let showFeedInspector = "showFeedInspector"
    }

    private var topShowBarsView: UIView!
    private var bottomShowBarsView: UIView!
    private var topShowBarsViewConstraint: NSLayoutConstraint!
    private var bottomShowBarsViewConstraint: NSLayoutConstraint!

    private var webView: PreloadedWebView? {
        view.subviews[0] as? PreloadedWebView
    }

    private lazy var contextMenuInteraction = UIContextMenuInteraction(delegate: self)
    private var isFullScreenAvailable: Bool {
        AppDefaults.shared.articleFullscreenAvailable && traitCollection.userInterfaceIdiom == .phone && self
            .coordinator.isRootSplitCollapsed
    }

    private lazy var articleIconSchemeHandler = ArticleIconSchemeHandler(coordinator: coordinator)
    private lazy var transition = ImageTransition(controller: self)
    private var clickedImageCompletion: (() -> Void)?

    weak var coordinator: SceneCoordinator!

    private(set) var article: Article?

    let scrollPositionQueue = CoalescingQueue(name: "Article Scroll Position", interval: 0.3, maxInterval: 0.3)
    var windowScrollY = 0 {
        didSet {
            if self.windowScrollY != AppDefaults.shared.articleWindowScrollY {
                AppDefaults.shared.articleWindowScrollY = self.windowScrollY
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.feedIconDidBecomeAvailable(_:)),
            name: .feedIconDidBecomeAvailable,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.avatarDidBecomeAvailable(_:)),
            name: .avatarDidBecomeAvailable,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.faviconDidBecomeAvailable(_:)),
            name: .FaviconDidBecomeAvailable,
            object: nil
        )

        // Configure the tap zones
        configureTopShowBarsView()
        configureBottomShowBarsView()

        loadWebView()
    }

    // MARK: Notifications

    @objc
    func feedIconDidBecomeAvailable(_: Notification) {
        reloadArticleImage()
    }

    @objc
    func avatarDidBecomeAvailable(_: Notification) {
        reloadArticleImage()
    }

    @objc
    func faviconDidBecomeAvailable(_: Notification) {
        reloadArticleImage()
    }

    // MARK: Actions

    @objc
    func showBars(_: Any) {
        self.showBars()
    }

    // MARK: API

    func setArticle(_ article: Article?, updateView: Bool = true) {
        if article != self.article {
            self.article = article
            if updateView {
                self.windowScrollY = 0
                loadWebView()
            }
        }
    }

    func setScrollPosition(articleWindowScrollY: Int) {
        self.windowScrollY = articleWindowScrollY
        loadWebView()
    }

    func focus() {
        self.webView?.becomeFirstResponder()
    }

    func canScrollDown() -> Bool {
        guard let webView else { return false }
        return webView.scrollView.contentOffset.y < finalScrollPosition(scrollingUp: false)
    }

    func canScrollUp() -> Bool {
        guard let webView else { return false }
        return webView.scrollView.contentOffset.y > finalScrollPosition(scrollingUp: true)
    }

    private func scrollPage(up scrollingUp: Bool) {
        guard let webView, let windowScene = webView.window?.windowScene else {
            return
        }

        let overlap = 2 * UIFont.systemFont(ofSize: UIFont.systemFontSize).lineHeight * windowScene.screen.scale
        let scrollToY: CGFloat = {
            let scrollDistance = webView.scrollView.layoutMarginsGuide.layoutFrame.height - overlap
            let fullScroll = webView.scrollView.contentOffset.y + (scrollingUp ? -scrollDistance : scrollDistance)
            let final = finalScrollPosition(scrollingUp: scrollingUp)
            return (scrollingUp ? fullScroll > final : fullScroll < final) ? fullScroll : final
        }()

        let convertedPoint = self.view.convert(CGPoint(x: 0, y: 0), to: webView.scrollView)
        let scrollToPoint = CGPoint(x: convertedPoint.x, y: scrollToY)
        webView.scrollView.setContentOffset(scrollToPoint, animated: true)
    }

    func scrollPageDown() {
        self.scrollPage(up: false)
    }

    func scrollPageUp() {
        self.scrollPage(up: true)
    }

    func hideClickedImage() {
        self.webView?.evaluateJavaScript("hideClickedImage();")
    }

    func showClickedImage(completion: @escaping () -> Void) {
        self.clickedImageCompletion = completion
        self.webView?.evaluateJavaScript("showClickedImage();")
    }

    func fullReload() {
        loadWebView(replaceExistingWebView: true)
    }

    func showBars() {
        AppDefaults.shared.articleFullscreenEnabled = false
        self.coordinator.showStatusBar()
        self.topShowBarsViewConstraint?.constant = 0
        self.bottomShowBarsViewConstraint?.constant = 0
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationController?.setToolbarHidden(false, animated: true)
        configureContextMenuInteraction()
    }

    func hideBars() {
        if self.isFullScreenAvailable {
            AppDefaults.shared.articleFullscreenEnabled = true
            self.coordinator.hideStatusBar()
            self.topShowBarsViewConstraint?.constant = -44.0
            self.bottomShowBarsViewConstraint?.constant = 44.0
            navigationController?.setNavigationBarHidden(true, animated: true)
            navigationController?.setToolbarHidden(true, animated: true)
            configureContextMenuInteraction()
        }
    }

    func stopWebViewActivity() {
        if let webView {
            stopMediaPlayback(webView)
            cancelImageLoad(webView)
        }
    }

    func showActivityDialog(popOverBarButtonItem: UIBarButtonItem? = nil) {
        guard let url = article?.preferredURL else { return }
        let itemSource = ArticleActivityItemSource(url: url, subject: article?.title)
        let titleSource = TitleActivityItemSource(title: article?.title)
        let activityViewController = UIActivityViewController(
            activityItems: [titleSource, itemSource],
            applicationActivities: [FindInArticleActivity(), OpenInBrowserActivity()]
        )
        activityViewController.popoverPresentationController?.barButtonItem = popOverBarButtonItem
        present(activityViewController, animated: true)
    }

    func openInAppBrowser() {
        guard let url = article?.preferredURL else { return }
        if AppDefaults.shared.useSystemBrowser {
            UIApplication.shared.open(url, options: [:])
        } else {
            openURLInSafariViewController(url)
        }
    }
}

// MARK: UIContextMenuInteractionDelegate

extension WebViewController: UIContextMenuInteractionDelegate {
    func contextMenuInteraction(
        _: UIContextMenuInteraction,
        configurationForMenuAtLocation _: CGPoint
    )
        -> UIContextMenuConfiguration?
    {
        UIContextMenuConfiguration(identifier: nil, previewProvider: contextMenuPreviewProvider) { [weak self] _ in
            guard let self else { return nil }

            var menus = [UIMenu]()

            var navActions = [UIAction]()
            if let action = self.prevArticleAction() {
                navActions.append(action)
            }
            if let action = self.nextArticleAction() {
                navActions.append(action)
            }
            if !navActions.isEmpty {
                menus.append(UIMenu(title: "", options: .displayInline, children: navActions))
            }

            var toggleActions = [UIAction]()
            if let action = self.toggleReadAction() {
                toggleActions.append(action)
            }
            toggleActions.append(self.toggleStarredAction())
            menus.append(UIMenu(title: "", options: .displayInline, children: toggleActions))

            if let action = self.nextUnreadArticleAction() {
                menus.append(UIMenu(title: "", options: .displayInline, children: [action]))
            }

            menus.append(UIMenu(title: "", options: .displayInline, children: [self.shareAction()]))

            return UIMenu(title: "", children: menus)
        }
    }

    func contextMenuInteraction(
        _: UIContextMenuInteraction,
        willPerformPreviewActionForMenuWith _: UIContextMenuConfiguration,
        animator _: UIContextMenuInteractionCommitAnimating
    ) {
        self.coordinator.showBrowserForCurrentArticle()
    }
}

// MARK: WKNavigationDelegate

extension WebViewController: WKNavigationDelegate {
    func webView(_: WKWebView, didFinish _: WKNavigation!) {
        for (index, view) in view.subviews.enumerated() {
            if index != 0, let oldWebView = view as? PreloadedWebView {
                oldWebView.removeFromSuperview()
            }
        }
    }

    func webView(
        _: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
        if navigationAction.navigationType == .linkActivated {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if components?.scheme == "http" || components?.scheme == "https" {
                decisionHandler(.cancel)
                if AppDefaults.shared.useSystemBrowser {
                    UIApplication.shared.open(url, options: [:])
                } else {
                    UIApplication.shared.open(url, options: [.universalLinksOnly: true]) { didOpen in
                        guard didOpen == false else {
                            return
                        }
                        self.openURLInSafariViewController(url)
                    }
                }

            } else if components?.scheme == "mailto" {
                decisionHandler(.cancel)

                guard let emailAddress = url.percentEncodedEmailAddress else {
                    return
                }

                if UIApplication.shared.canOpenURL(emailAddress) {
                    UIApplication.shared.open(
                        emailAddress,
                        options: [.universalLinksOnly: false],
                        completionHandler: nil
                    )
                } else {
                    let alert = UIAlertController(
                        title: NSLocalizedString("Error", comment: "Error"),
                        message: NSLocalizedString(
                            "This device cannot send emails.",
                            comment: "This device cannot send emails."
                        ),
                        preferredStyle: .alert
                    )
                    alert.addAction(.init(
                        title: NSLocalizedString("Dismiss", comment: "Dismiss"),
                        style: .cancel,
                        handler: nil
                    ))
                    self.present(alert, animated: true, completion: nil)
                }
            } else if components?.scheme == "tel" {
                decisionHandler(.cancel)

                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [.universalLinksOnly: false], completionHandler: nil)
                }

            } else {
                decisionHandler(.allow)
            }
        } else {
            decisionHandler(.allow)
        }
    }

    func webViewWebContentProcessDidTerminate(_: WKWebView) {
        self.fullReload()
    }
}

// MARK: WKUIDelegate

extension WebViewController: WKUIDelegate {
    func webView(
        _: WKWebView,
        contextMenuForElement _: WKContextMenuElementInfo,
        willCommitWithAnimator _: UIContextMenuInteractionCommitAnimating
    ) {
        // We need to have at least an unimplemented WKUIDelegate assigned to the WKWebView.  This makes the
        // link preview launch Safari when the link preview is tapped.  In theory, you should be able to get
        // the link from the elementInfo above and transition to SFSafariViewController instead of launching
        // Safari.  As the time of this writing, the link in elementInfo is always nil.  ¯\_(ツ)_/¯
    }

    func webView(
        _: WKWebView,
        createWebViewWith _: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures _: WKWindowFeatures
    )
        -> WKWebView?
    {
        guard let url = navigationAction.request.url else {
            return nil
        }

        openURL(url)
        return nil
    }
}

// MARK: WKScriptMessageHandler

extension WebViewController: WKScriptMessageHandler {
    func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case MessageName.imageWasShown:
            self.clickedImageCompletion?()
        case MessageName.imageWasClicked:
            imageWasClicked(body: message.body as? String)
        case MessageName.showFeedInspector:
            if let feed = article?.feed {
                self.coordinator.showFeedInspector(for: feed)
            }
        default:
            return
        }
    }
}

// MARK: UIViewControllerTransitioningDelegate

extension WebViewController: UIViewControllerTransitioningDelegate {
    func animationController(
        forPresented _: UIViewController,
        presenting _: UIViewController,
        source _: UIViewController
    )
        -> UIViewControllerAnimatedTransitioning?
    {
        self.transition.presenting = true
        return self.transition
    }

    func animationController(forDismissed _: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        self.transition.presenting = false
        return self.transition
    }
}

// MARK:

extension WebViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_: UIScrollView) {
        self.scrollPositionQueue.add(self, #selector(self.scrollPositionDidChange))
    }

    @objc
    func scrollPositionDidChange() {
        self.webView?.evaluateJavaScript("window.scrollY") { scrollY, error in
            guard error == nil else { return }
            let javascriptScrollY = scrollY as? Int ?? 0
            // I don't know why this value gets returned sometimes, but it is in error
            guard javascriptScrollY != 33_554_432 else { return }
            self.windowScrollY = javascriptScrollY
        }
    }
}

// MARK: JSON

private struct ImageClickMessage: Codable {
    let x: Float
    let y: Float
    let width: Float
    let height: Float
    let imageTitle: String?
    let imageURL: String
}

// MARK: Private

extension WebViewController {
    private func loadWebView(replaceExistingWebView: Bool = false) {
        guard isViewLoaded else { return }

        if !replaceExistingWebView, let webView {
            self.renderPage(webView)
            return
        }

        self.coordinator.webViewProvider.dequeueWebView { webView in
            webView.ready {
                // Add the webview
                webView.translatesAutoresizingMaskIntoConstraints = false
                self.view.insertSubview(webView, at: 0)
                NSLayoutConstraint.activate([
                    self.view.leadingAnchor.constraint(equalTo: webView.leadingAnchor),
                    self.view.trailingAnchor.constraint(equalTo: webView.trailingAnchor),
                    self.view.topAnchor.constraint(equalTo: webView.topAnchor),
                    self.view.bottomAnchor.constraint(equalTo: webView.bottomAnchor),
                ])

                // UISplitViewController reports the wrong size to WKWebView which can cause horizontal
                // rubberbanding on the iPad.  This interferes with our UIPageViewController preventing
                // us from easily swiping between WKWebViews.  This hack fixes that.
                webView.scrollView.contentInset = UIEdgeInsets(top: 0, left: -1, bottom: 0, right: 0)

                webView.scrollView.setZoomScale(1.0, animated: false)

                self.view.setNeedsLayout()
                self.view.layoutIfNeeded()

                // Configure the webview
                webView.navigationDelegate = self
                webView.uiDelegate = self
                webView.scrollView.delegate = self
                self.configureContextMenuInteraction()

                // Remove possible existing message handlers
                webView.configuration.userContentController
                    .removeScriptMessageHandler(forName: MessageName.imageWasClicked)
                webView.configuration.userContentController
                    .removeScriptMessageHandler(forName: MessageName.imageWasShown)
                webView.configuration.userContentController
                    .removeScriptMessageHandler(forName: MessageName.showFeedInspector)

                // Add handlers
                webView.configuration.userContentController.add(
                    WrapperScriptMessageHandler(self),
                    name: MessageName.imageWasClicked
                )
                webView.configuration.userContentController.add(
                    WrapperScriptMessageHandler(self),
                    name: MessageName.imageWasShown
                )
                webView.configuration.userContentController.add(
                    WrapperScriptMessageHandler(self),
                    name: MessageName.showFeedInspector
                )

                self.renderPage(webView)
            }
        }
    }

    private func renderPage(_ webView: PreloadedWebView?) {
        guard let webView else { return }

        let rendering: ArticleRenderer.Rendering = if let article {
            ArticleRenderer.articleHTML(article: article)
        } else {
            ArticleRenderer.noSelectionHTML()
        }

        let substitutions = [
            "title": rendering.title,
            "baseURL": rendering.baseURL,
            "style": rendering.style,
            "body": rendering.html,
            "windowScrollY": String(self.windowScrollY),
        ]

        var html = try! MacroProcessor.renderedText(
            withTemplate: ArticleRenderer.page.html,
            substitutions: substitutions
        )
        html = ArticleRenderingSpecialCases.filterHTMLIfNeeded(baseURL: rendering.baseURL, html: html)
        webView.loadHTMLString(html, baseURL: ArticleRenderer.page.baseURL)
    }

    private func finalScrollPosition(scrollingUp: Bool) -> CGFloat {
        guard let webView else { return 0 }

        if scrollingUp {
            return -webView.scrollView.safeAreaInsets.top
        } else {
            return webView.scrollView.contentSize.height - webView.scrollView.bounds.height + webView.scrollView
                .safeAreaInsets.bottom
        }
    }

    private func reloadArticleImage() {
        guard let article else { return }

        var components = URLComponents()
        components.scheme = ArticleRenderer.imageIconScheme
        components.path = article.articleID

        if let imageSrc = components.string {
            self.webView?.evaluateJavaScript("reloadArticleImage(\"\(imageSrc)\")")
        }
    }

    private func imageWasClicked(body: String?) {
        guard let webView, let body else { return }

        let data = Data(body.utf8)
        guard let clickMessage = try? JSONDecoder().decode(ImageClickMessage.self, from: data) else {
            return
        }

        guard let imageURL = URL(string: clickMessage.imageURL) else { return }

        Downloader.shared.download(imageURL) { [weak self] data, _, error in
            guard
                let self, let data, error == nil, !data.isEmpty,
                let image = UIImage(data: data) else
            {
                return
            }
            self.showFullScreenImage(image: image, clickMessage: clickMessage, webView: webView)
        }
    }

    private func showFullScreenImage(image: UIImage, clickMessage: ImageClickMessage, webView: WKWebView) {
        let y = CGFloat(clickMessage.y) + webView.safeAreaInsets.top
        let rect = CGRect(
            x: CGFloat(clickMessage.x),
            y: y,
            width: CGFloat(clickMessage.width),
            height: CGFloat(clickMessage.height)
        )
        self.transition.originFrame = webView.convert(rect, to: nil)

        if navigationController?.navigationBar.isHidden ?? false {
            self.transition.maskFrame = webView.convert(webView.frame, to: nil)
        } else {
            self.transition.maskFrame = webView.convert(webView.safeAreaLayoutGuide.layoutFrame, to: nil)
        }

        self.transition.originImage = image

        self.coordinator.showFullScreenImage(
            image: image,
            imageTitle: clickMessage.imageTitle,
            transitioningDelegate: self
        )
    }

    private func stopMediaPlayback(_ webView: WKWebView) {
        webView.evaluateJavaScript("stopMediaPlayback();")
    }

    private func cancelImageLoad(_ webView: WKWebView) {
        webView.evaluateJavaScript("cancelImageLoad();")
    }

    private func configureTopShowBarsView() {
        self.topShowBarsView = UIView()
        self.topShowBarsView.backgroundColor = .clear
        self.topShowBarsView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(self.topShowBarsView)

        if AppDefaults.shared.logicalArticleFullscreenEnabled {
            self.topShowBarsViewConstraint = view.topAnchor.constraint(
                equalTo: self.topShowBarsView.bottomAnchor,
                constant: -44.0
            )
        } else {
            self.topShowBarsViewConstraint = view.topAnchor.constraint(
                equalTo: self.topShowBarsView.bottomAnchor,
                constant: 0.0
            )
        }

        NSLayoutConstraint.activate([
            self.topShowBarsViewConstraint,
            view.leadingAnchor.constraint(equalTo: self.topShowBarsView.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: self.topShowBarsView.trailingAnchor),
            self.topShowBarsView.heightAnchor.constraint(equalToConstant: 44.0),
        ])
        self.topShowBarsView.addGestureRecognizer(UITapGestureRecognizer(
            target: self,
            action: #selector(self.showBars(_:))
        ))
    }

    private func configureBottomShowBarsView() {
        self.bottomShowBarsView = UIView()
        self.topShowBarsView.backgroundColor = .clear
        self.bottomShowBarsView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(self.bottomShowBarsView)
        if AppDefaults.shared.logicalArticleFullscreenEnabled {
            self.bottomShowBarsViewConstraint = view.bottomAnchor.constraint(
                equalTo: self.bottomShowBarsView.topAnchor,
                constant: 44.0
            )
        } else {
            self.bottomShowBarsViewConstraint = view.bottomAnchor.constraint(
                equalTo: self.bottomShowBarsView.topAnchor,
                constant: 0.0
            )
        }
        NSLayoutConstraint.activate([
            self.bottomShowBarsViewConstraint,
            view.leadingAnchor.constraint(equalTo: self.bottomShowBarsView.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: self.bottomShowBarsView.trailingAnchor),
            self.bottomShowBarsView.heightAnchor.constraint(equalToConstant: 44.0),
        ])
        self.bottomShowBarsView.addGestureRecognizer(UITapGestureRecognizer(
            target: self,
            action: #selector(self.showBars(_:))
        ))
    }

    private func configureContextMenuInteraction() {
        if self.isFullScreenAvailable {
            if navigationController?.isNavigationBarHidden ?? false {
                self.webView?.addInteraction(self.contextMenuInteraction)
            } else {
                self.webView?.removeInteraction(self.contextMenuInteraction)
            }
        }
    }

    private func contextMenuPreviewProvider() -> UIViewController {
        let previewProvider = ContextMenuPreviewViewController()
        previewProvider.article = self.article
        return previewProvider
    }

    private func prevArticleAction() -> UIAction? {
        guard self.coordinator.isPrevArticleAvailable else { return nil }
        let title = NSLocalizedString("Previous Article", comment: "Previous Article")
        return UIAction(title: title, image: Assets.Images.prevArticle) { [weak self] _ in
            self?.coordinator.selectPrevArticle()
        }
    }

    private func nextArticleAction() -> UIAction? {
        guard self.coordinator.isNextArticleAvailable else { return nil }
        let title = NSLocalizedString("Next Article", comment: "Next Article")
        return UIAction(title: title, image: Assets.Images.nextArticle) { [weak self] _ in
            self?.coordinator.selectNextArticle()
        }
    }

    private func toggleReadAction() -> UIAction? {
        guard let article, !article.status.read || article.isAvailableToMarkUnread else { return nil }

        let title = article.status
            .read ? NSLocalizedString("Mark as Unread", comment: "Mark as Unread") : NSLocalizedString(
                "Mark as Read",
                comment: "Mark as Read"
            )
        let readImage = article.status.read ? Assets.Images.circleClosed : Assets.Images.circleOpen
        return UIAction(title: title, image: readImage) { [weak self] _ in
            self?.coordinator.toggleReadForCurrentArticle()
        }
    }

    private func toggleStarredAction() -> UIAction {
        let starred = self.article?.status.starred ?? false
        let title = starred ? NSLocalizedString("Mark as Unstarred", comment: "Mark as Unstarred") : NSLocalizedString(
            "Mark as Starred",
            comment: "Mark as Starred"
        )
        let starredImage = starred ? Assets.Images.starOpen : Assets.Images.starClosed
        return UIAction(title: title, image: starredImage) { [weak self] _ in
            self?.coordinator.toggleStarredForCurrentArticle()
        }
    }

    private func nextUnreadArticleAction() -> UIAction? {
        guard self.coordinator.isAnyUnreadAvailable else { return nil }
        let title = NSLocalizedString("Next Unread Article", comment: "Next Unread Article")
        return UIAction(title: title, image: Assets.Images.nextUnread) { [weak self] _ in
            self?.coordinator.selectNextUnread()
        }
    }

    private func shareAction() -> UIAction {
        let title = NSLocalizedString("Share", comment: "Share")
        return UIAction(title: title, image: Assets.Images.share) { [weak self] _ in
            self?.showActivityDialog()
        }
    }

    // If the resource cannot be opened with an installed app, present the web view.
    private func openURL(_ url: URL) {
        UIApplication.shared.open(url, options: [.universalLinksOnly: true]) { didOpen in
            assert(Thread.isMainThread)
            guard didOpen == false else {
                return
            }
            self.openURLInSafariViewController(url)
        }
    }

    private func openURLInSafariViewController(_ url: URL) {
        guard let viewController = SFSafariViewController.safeSafariViewController(url) else {
            return
        }
        present(viewController, animated: true)
    }
}

// MARK: Find in Article

private struct FindInArticleOptions: Codable {
    var text: String
    var caseSensitive = false
    var regex = false
}

struct FindInArticleState: Codable {
    struct WebViewClientRect: Codable {
        let x: Double
        let y: Double
        let width: Double
        let height: Double
    }

    struct FindInArticleResult: Codable {
        let rects: [WebViewClientRect]
        let bounds: WebViewClientRect
        let index: UInt
        let matchGroups: [String]
    }

    let index: UInt?
    let results: [FindInArticleResult]
    let count: UInt
}

extension WebViewController {
    func searchText(_ searchText: String, completionHandler: @escaping (FindInArticleState) -> Void) {
        guard let json = try? JSONEncoder().encode(FindInArticleOptions(text: searchText)) else {
            return
        }
        let encoded = json.base64EncodedString()

        self.webView?.evaluateJavaScript("updateFind(\"\(encoded)\")") {
            result, error in
            guard
                error == nil,
                let b64 = result as? String,
                let rawData = Data(base64Encoded: b64),
                let findState = try? JSONDecoder().decode(FindInArticleState.self, from: rawData) else
            {
                return
            }

            completionHandler(findState)
        }
    }

    func endSearch() {
        self.webView?.evaluateJavaScript("endFind()")
    }

    func selectNextSearchResult() {
        self.webView?.evaluateJavaScript("selectNextResult()")
    }

    func selectPreviousSearchResult() {
        self.webView?.evaluateJavaScript("selectPreviousResult()")
    }
}

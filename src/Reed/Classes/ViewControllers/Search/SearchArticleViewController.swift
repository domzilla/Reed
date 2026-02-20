//
//  SearchArticleViewController.swift
//  Reed
//
//  Created by Dominic Rodemer on 20/02/2026.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import UIKit

final class SearchArticleViewController: BaseArticleViewController {
    // MARK: - Properties

    private var webViewController: WebViewController?

    override var currentWebViewController: WebViewController? {
        self.webViewController
    }

    // MARK: - Initialization

    init(article: Article, coordinator: SceneCoordinator) {
        super.init(nibName: nil, bundle: nil)
        self.article = article
        self.coordinator = coordinator
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("Use init(article:coordinator:)")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        toolbarItems = [
            self.readBarButtonItem,
            flexSpace,
            self.starBarButtonItem,
            flexSpace,
            self.actionBarButtonItem,
        ]

        let webVC = WebViewController()
        webVC.coordinator = self.coordinator
        webVC.setArticle(self.article)

        addChild(webVC)
        webVC.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webVC.view)
        NSLayoutConstraint.activate([
            webVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            webVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        webVC.didMove(toParent: self)
        self.webViewController = webVC

        if let article {
            markArticles(Set([article]), statusKey: .read, flag: true)
        }

        self.updateUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setToolbarHidden(false, animated: animated)
    }
}

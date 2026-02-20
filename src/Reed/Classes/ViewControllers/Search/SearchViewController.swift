//
//  SearchViewController.swift
//  Reed
//
//  Created by Dominic Rodemer on 20/02/2026.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import DZFoundation
import UIKit

final class SearchViewController: UITableViewController {
    // MARK: - Constants

    static let preferredContentSizeForFormSheetDisplay = CGSize(width: 460.0, height: 600.0)

    // MARK: - Properties

    weak var coordinator: SceneCoordinator?

    private let searchScope: SearchScope
    private let articleIDs: Set<String>?

    private var articles = ArticleArray()
    private var searchTask: Task<Void, Never>?

    private lazy var searchBar: UISearchBar = {
        let bar = UISearchBar()
        bar.delegate = self
        bar.autocapitalizationType = .none
        bar.autocorrectionType = .no
        switch self.searchScope {
        case .global:
            bar.placeholder = NSLocalizedString("Search All Articles", comment: "Search All Articles")
        case .timeline:
            bar.placeholder = NSLocalizedString("Search Articles", comment: "Search Articles")
        }
        return bar
    }()

    // MARK: - Initialization

    init(scope: SearchScope, articleIDs: Set<String>? = nil) {
        self.searchScope = scope
        self.articleIDs = articleIDs
        super.init(style: .plain)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("Use init(scope:articleIDs:)")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.titleView = self.searchBar
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(self.dismissSearch)
        )

        self.tableView.register(MainTimelineIconFeedCell.self, forCellReuseIdentifier: "MainTimelineIconFeedCell")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.searchBar.becomeFirstResponder()
    }

    // MARK: - Actions

    @objc
    private func dismissSearch() {
        self.searchTask?.cancel()
        dismiss(animated: true)
    }

    // MARK: - Search

    private func performSearch(_ searchString: String) {
        self.searchTask?.cancel()

        guard searchString.count >= 3 else {
            self.articles = []
            self.tableView.reloadData()
            return
        }

        self.searchTask = Task { @MainActor in
            do {
                let results: Set<Article>
                switch self.searchScope {
                case .global:
                    results = try await DataStore.shared.fetchArticlesAsync(.search(searchString))
                case .timeline:
                    guard let articleIDs = self.articleIDs else { return }
                    results = try await DataStore.shared.fetchArticlesAsync(
                        .searchWithArticleIDs(searchString, articleIDs)
                    )
                }

                guard !Task.isCancelled else { return }

                self.articles = Array(results).sortedByDate(.orderedDescending)
                self.tableView.reloadData()
            } catch {
                DZErrorLog(error)
            }
        }
    }

    // MARK: - UITableViewDataSource

    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        self.articles.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: "MainTimelineIconFeedCell",
            for: indexPath
        ) as! MainTimelineIconFeedCell

        let article = self.articles[indexPath.row]
        let iconImage = article.iconImage()
        let showIcon = iconImage != nil
        let isCompact = traitCollection.horizontalSizeClass == .compact
        let cellData = MainTimelineCellData(
            article: article,
            showFeedName: .feed,
            feedName: article.feed?.nameForDisplay,
            byline: article.byline(),
            iconImage: iconImage,
            showIcon: showIcon,
            numberOfLines: isCompact ? 2 : 3,
            iconSize: isCompact ? .medium : .large
        )
        cell.cellData = cellData
        return cell
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let article = self.articles[indexPath.row]
        self.searchTask?.cancel()

        dismiss(animated: true) { [weak self] in
            guard let coordinator = self?.coordinator else { return }

            switch self?.searchScope {
            case .timeline:
                coordinator.selectArticle(article, animations: [.navigation, .scroll])

            case .global:
                guard let feed = article.feed else { return }
                coordinator.discloseFeed(feed, animations: [.navigation]) {
                    coordinator.selectArticleInCurrentFeed(article.articleID)
                }

            case .none:
                break
            }
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - UISearchBarDelegate

extension SearchViewController: UISearchBarDelegate {
    func searchBar(_: UISearchBar, textDidChange searchText: String) {
        self.performSearch(searchText)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

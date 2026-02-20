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

    private lazy var searchTextField: UISearchTextField = {
        let field = UISearchTextField()
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.addTarget(self, action: #selector(self.searchTextDidChange(_:)), for: .editingChanged)
        switch self.searchScope {
        case .global:
            field.placeholder = NSLocalizedString("Search All Articles", comment: "Search All Articles")
        case .timeline:
            field.placeholder = NSLocalizedString("Search Articles", comment: "Search Articles")
        }
        return field
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

        title = NSLocalizedString("Search", comment: "Search")
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(self.dismissSearch)
        )

        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 52))
        self.searchTextField.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(self.searchTextField)
        NSLayoutConstraint.activate([
            self.searchTextField.leadingAnchor.constraint(equalTo: headerView.layoutMarginsGuide.leadingAnchor),
            self.searchTextField.trailingAnchor.constraint(equalTo: headerView.layoutMarginsGuide.trailingAnchor),
            self.searchTextField.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 8),
            self.searchTextField.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -8),
        ])
        self.tableView.tableHeaderView = headerView

        self.tableView.register(MainTimelineIconFeedCell.self, forCellReuseIdentifier: "MainTimelineIconFeedCell")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setToolbarHidden(true, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.searchTextField.becomeFirstResponder()
    }

    // MARK: - Actions

    @objc
    private func dismissSearch() {
        self.searchTask?.cancel()
        dismiss(animated: true)
    }

    @objc
    private func searchTextDidChange(_ textField: UISearchTextField) {
        self.performSearch(textField.text ?? "")
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

        guard let coordinator else { return }
        let articleVC = SearchArticleViewController(article: article, coordinator: coordinator)
        navigationController?.pushViewController(articleVC, animated: true)

        tableView.deselectRow(at: indexPath, animated: true)
    }
}

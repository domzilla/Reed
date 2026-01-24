//
//  ContextMenuPreviewViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 11/25/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

final class ContextMenuPreviewViewController: UIViewController {
    var article: Article!

    // MARK: - UI Elements

    private lazy var blogNameLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .headline)
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var blogAuthorLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .secondaryLabel
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var articleTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.numberOfLines = 3
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var dateTimeLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = .secondaryLabel
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var iconView: IconView = {
        let icon = IconView()
        icon.translatesAutoresizingMaskIntoConstraints = false
        return icon
    }()

    // MARK: - Initialization

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("Use init()")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        self.blogNameLabel.text = self.article.feed?.nameForDisplay ?? ""
        self.blogAuthorLabel.text = self.article.byline()
        self.articleTitleLabel.text = self.article.title ?? ""

        self.iconView.iconImage = self.article.iconImage()

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .medium
        self.dateTimeLabel.text = dateFormatter.string(from: self.article.logicalDatePublished)

        view.addSubview(self.blogNameLabel)
        view.addSubview(self.blogAuthorLabel)
        view.addSubview(self.articleTitleLabel)
        view.addSubview(self.dateTimeLabel)
        view.addSubview(self.iconView)

        NSLayoutConstraint.activate([
            self.iconView.widthAnchor.constraint(equalToConstant: 48),
            self.iconView.heightAnchor.constraint(equalToConstant: 48),
            self.iconView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            self.iconView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),

            self.blogNameLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            self.blogNameLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            self.blogNameLabel.trailingAnchor.constraint(lessThanOrEqualTo: self.iconView.leadingAnchor, constant: -8),

            self.blogAuthorLabel.topAnchor.constraint(equalTo: self.blogNameLabel.bottomAnchor, constant: 2),
            self.blogAuthorLabel.leadingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.leadingAnchor,
                constant: 20
            ),
            self.blogAuthorLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: self.iconView.leadingAnchor,
                constant: -8
            ),

            self.articleTitleLabel.topAnchor.constraint(equalTo: self.blogAuthorLabel.bottomAnchor, constant: 8),
            self.articleTitleLabel.leadingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.leadingAnchor,
                constant: 20
            ),
            self.articleTitleLabel.trailingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.trailingAnchor,
                constant: -20
            ),

            self.dateTimeLabel.topAnchor.constraint(equalTo: self.articleTitleLabel.bottomAnchor, constant: 8),
            self.dateTimeLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            self.dateTimeLabel.trailingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.trailingAnchor,
                constant: -20
            ),
        ])

        // When in landscape the context menu preview will force this controller into a tiny
        // view space.  If it is documented anywhere what that is, I haven't found it.  This
        // set of magic numbers is what I worked out by testing a variety of phones.

        let width: CGFloat
        let heightPadding: CGFloat
        if view.bounds.width > view.bounds.height {
            width = 260
            heightPadding = 16
            view.widthAnchor.constraint(equalToConstant: width).isActive = true
        } else {
            width = view.bounds.width
            heightPadding = 8
        }

        view.setNeedsLayout()
        view.layoutIfNeeded()
        preferredContentSize = CGSize(width: width, height: self.dateTimeLabel.frame.maxY + heightPadding)
    }
}

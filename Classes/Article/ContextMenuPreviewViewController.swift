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
	required init?(coder: NSCoder) {
		fatalError("Use init()")
	}

	// MARK: - Lifecycle

	override func viewDidLoad() {
        super.viewDidLoad()

		view.backgroundColor = .systemBackground

		blogNameLabel.text = article.feed?.nameForDisplay ?? ""
		blogAuthorLabel.text = article.byline()
		articleTitleLabel.text = article.title ?? ""

		iconView.iconImage = article.iconImage()

		let dateFormatter = DateFormatter()
		dateFormatter.dateStyle = .long
		dateFormatter.timeStyle = .medium
		dateTimeLabel.text = dateFormatter.string(from: article.logicalDatePublished)

		view.addSubview(blogNameLabel)
		view.addSubview(blogAuthorLabel)
		view.addSubview(articleTitleLabel)
		view.addSubview(dateTimeLabel)
		view.addSubview(iconView)

		NSLayoutConstraint.activate([
			iconView.widthAnchor.constraint(equalToConstant: 48),
			iconView.heightAnchor.constraint(equalToConstant: 48),
			iconView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
			iconView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),

			blogNameLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
			blogNameLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
			blogNameLabel.trailingAnchor.constraint(lessThanOrEqualTo: iconView.leadingAnchor, constant: -8),

			blogAuthorLabel.topAnchor.constraint(equalTo: blogNameLabel.bottomAnchor, constant: 2),
			blogAuthorLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
			blogAuthorLabel.trailingAnchor.constraint(lessThanOrEqualTo: iconView.leadingAnchor, constant: -8),

			articleTitleLabel.topAnchor.constraint(equalTo: blogAuthorLabel.bottomAnchor, constant: 8),
			articleTitleLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
			articleTitleLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),

			dateTimeLabel.topAnchor.constraint(equalTo: articleTitleLabel.bottomAnchor, constant: 8),
			dateTimeLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
			dateTimeLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
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
		preferredContentSize = CGSize(width: width, height: dateTimeLabel.frame.maxY + heightPadding)
    }

}

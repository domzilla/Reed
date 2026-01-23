//
//  MainTimelineIconFeedCell.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 19/07/2025.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import UIKit

class MainTimelineIconFeedCell: UITableViewCell {

	let articleTitle: UILabel = {
		let label = UILabel()
		label.font = .preferredFont(forTextStyle: .headline)
		label.adjustsFontForContentSizeCategory = true
		label.numberOfLines = 0
		label.translatesAutoresizingMaskIntoConstraints = false
		return label
	}()

	let authorByLine: UILabel = {
		let label = UILabel()
		label.font = .preferredFont(forTextStyle: .subheadline)
		label.textColor = .secondaryLabel
		label.adjustsFontForContentSizeCategory = true
		label.translatesAutoresizingMaskIntoConstraints = false
		return label
	}()

	let iconView: IconView = {
		let view = IconView()
		view.translatesAutoresizingMaskIntoConstraints = false
		return view
	}()

	let indicatorView: IconView = {
		let view = IconView()
		view.alpha = 0.0
		view.translatesAutoresizingMaskIntoConstraints = false
		return view
	}()

	let articleDate: UILabel = {
		let label = UILabel()
		label.font = .preferredFont(forTextStyle: .footnote)
		label.textColor = .secondaryLabel
		label.adjustsFontForContentSizeCategory = true
		label.translatesAutoresizingMaskIntoConstraints = false
		return label
	}()

	let metaDataStackView: UIStackView = {
		let stack = UIStackView()
		stack.axis = .horizontal
		stack.alignment = .center
		stack.distribution = .fill
		stack.spacing = 8
		stack.translatesAutoresizingMaskIntoConstraints = false
		return stack
	}()

	private var iconWidthConstraint: NSLayoutConstraint?
	private var iconHeightConstraint: NSLayoutConstraint?

	var cellData: MainTimelineCellData! {
		didSet {
			configure(cellData)
		}
	}

	var isPreview: Bool = false

	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
		setupViews()
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("Use init(style:reuseIdentifier:)")
	}

	private func setupViews() {
		metaDataStackView.addArrangedSubview(authorByLine)
		metaDataStackView.addArrangedSubview(articleDate)

		contentView.addSubview(indicatorView)
		contentView.addSubview(iconView)
		contentView.addSubview(articleTitle)
		contentView.addSubview(metaDataStackView)

		iconWidthConstraint = iconView.widthAnchor.constraint(equalToConstant: 48)
		iconHeightConstraint = iconView.heightAnchor.constraint(equalToConstant: 48)

		NSLayoutConstraint.activate([
			indicatorView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
			indicatorView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
			indicatorView.widthAnchor.constraint(equalToConstant: 10),
			indicatorView.heightAnchor.constraint(equalToConstant: 10),

			iconView.leadingAnchor.constraint(equalTo: indicatorView.trailingAnchor, constant: 8),
			iconView.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
			iconWidthConstraint!,
			iconHeightConstraint!,

			articleTitle.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
			articleTitle.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
			articleTitle.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),

			metaDataStackView.topAnchor.constraint(equalTo: articleTitle.bottomAnchor, constant: 4),
			metaDataStackView.leadingAnchor.constraint(equalTo: articleTitle.leadingAnchor),
			metaDataStackView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.layoutMarginsGuide.trailingAnchor),
			metaDataStackView.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),
		])

		configureStackView()
	}

	private func configureStackView() {
		switch traitCollection.preferredContentSizeCategory {
		case .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge, .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge:
			metaDataStackView.axis = .vertical
			metaDataStackView.alignment = .leading
			metaDataStackView.distribution = .fill
		default:
			metaDataStackView.axis = .horizontal
			metaDataStackView.alignment = .center
			metaDataStackView.distribution = .fill
		}
	}


	private func configure(_ cellData: MainTimelineCellData) {
		updateIndicatorView(cellData)
		articleTitle.numberOfLines = cellData.numberOfLines
		applyTitleTextWithAttributes(configurationState)

		if cellData.showFeedName == .feed {
			authorByLine.text = cellData.feedName
		} else if cellData.showFeedName == .byline {
			authorByLine.text = cellData.byline
		} else if cellData.showFeedName == .none {
			authorByLine.text = ""
		}

		setIconImage(cellData.iconImage, with: cellData.iconSize)

		articleDate.text = cellData.dateString
	}

	private func setIconImage(_ iconImage: IconImage?, with size: IconSize) {
		iconView.iconImage = iconImage
		updateIconViewSizeConstraints(to: size.size)
	}

	func setIconImage(_ iconImage: IconImage?) {
		iconView.iconImage = iconImage
	}

	private func updateIconViewSizeConstraints(to size: CGSize) {
		iconWidthConstraint?.constant = size.width
		iconHeightConstraint?.constant = size.height
		setNeedsLayout()
	}

	private func updateIndicatorView(_ cellData: MainTimelineCellData) {
		if cellData.read == false {
			if indicatorView.alpha == 0.0 {
				indicatorView.alpha = 1.0
			}
			UIView.animate(withDuration: 0.25) {
				self.indicatorView.iconImage = Assets.Images.unreadCellIndicator
				self.indicatorView.tintColor = Assets.Colors.secondaryAccent
			}
			return
		} else if cellData.starred {
			if indicatorView.alpha == 0.0 {
				indicatorView.alpha = 1.0
			}
			UIView.animate(withDuration: 0.25) {
				self.indicatorView.iconImage = Assets.Images.starredFeed
				self.indicatorView.tintColor = Assets.Colors.star
			}
			return
		} else if indicatorView.alpha == 1.0 {
			UIView.animate(withDuration: 0.25) {
				self.indicatorView.alpha = 0.0
				self.indicatorView.iconImage = nil
			}
		}
	}

	private func applyTitleTextWithAttributes(_ state: UICellConfigurationState) {
		let attributedCellText = NSMutableAttributedString()



		let isSelected = state.isSelected || state.isHighlighted || state.isFocused || state.isSwiped
		if cellData.title != "" {
			let paragraphStyle = NSMutableParagraphStyle()
			paragraphStyle.minimumLineHeight = UIFont.preferredFont(forTextStyle: .headline).pointSize
			paragraphStyle.maximumLineHeight = UIFont.preferredFont(forTextStyle: .headline).pointSize
			paragraphStyle.lineBreakMode = .byTruncatingTail
			let titleAttributes: [NSAttributedString.Key: Any] = [
				.font: UIFont.preferredFont(forTextStyle: .headline),
				.paragraphStyle: paragraphStyle,
				.foregroundColor: isSelected ? UIColor.white : UIColor.label
			]
			let titleWithNewline = cellData.title + (cellData.summary != "" ? "\n" : "" )
			let titleAttributed = NSAttributedString(string: titleWithNewline, attributes: titleAttributes)
			attributedCellText.append(titleAttributed)
		}
		if cellData.summary != "" {
			let paragraphStyle = NSMutableParagraphStyle()
			paragraphStyle.minimumLineHeight = UIFont.preferredFont(forTextStyle: .body).pointSize
			paragraphStyle.maximumLineHeight = UIFont.preferredFont(forTextStyle: .body).pointSize
			paragraphStyle.lineBreakMode = .byTruncatingTail
			let summaryAttributes: [NSAttributedString.Key: Any] = [
				.font: UIFont.preferredFont(forTextStyle: .body),
				.paragraphStyle: paragraphStyle,
				.foregroundColor: isSelected ? UIColor.white : UIColor.label
			]
			let summaryAttributed = NSAttributedString(string: cellData.summary, attributes: summaryAttributes)
			attributedCellText.append(summaryAttributed)
		}
		articleTitle.attributedText = attributedCellText
	}

	override func updateConfiguration(using state: UICellConfigurationState) {
		super.updateConfiguration(using: state)

		var backgroundConfig = UIBackgroundConfiguration.listCell().updated(for: state)
		backgroundConfig.cornerRadius = 20
		if traitCollection.userInterfaceIdiom == .pad {
			backgroundConfig.edgesAddingLayoutMarginsToBackgroundInsets = [.leading, .trailing]
			backgroundConfig.backgroundInsets = NSDirectionalEdgeInsets(top: 0, leading: !isPreview ? -4 : -12, bottom: 0, trailing: !isPreview ? -4 : -12)
		}

		if state.isSelected || state.isHighlighted || state.isFocused || state.isSwiped {
			backgroundConfig.backgroundColor = Assets.Colors.primaryAccent
			applyTitleTextWithAttributes(state)
			articleDate.textColor = .lightText
			authorByLine.textColor = .lightText
		} else {
			applyTitleTextWithAttributes(state)
			articleDate.textColor = .secondaryLabel
			authorByLine.textColor = .secondaryLabel
		}

		self.backgroundConfiguration = backgroundConfig

	}

}

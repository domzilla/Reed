//
//  MainTimelineIconFeedCell.swift
//  Reed
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

    let articleSummary: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 2
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
    private var titleLeadingWithIcon: NSLayoutConstraint?
    private var titleLeadingWithoutIcon: NSLayoutConstraint?

    var cellData: MainTimelineCellData! {
        didSet {
            self.configure(self.cellData)
        }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.setupViews()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("Use init(style:reuseIdentifier:)")
    }

    private func setupViews() {
        self.metaDataStackView.addArrangedSubview(self.authorByLine)
        self.metaDataStackView.addArrangedSubview(self.articleDate)

        contentView.addSubview(self.indicatorView)
        contentView.addSubview(self.iconView)
        contentView.addSubview(self.articleTitle)
        contentView.addSubview(self.articleSummary)
        contentView.addSubview(self.metaDataStackView)

        self.iconWidthConstraint = self.iconView.widthAnchor.constraint(equalToConstant: 48)
        self.iconHeightConstraint = self.iconView.heightAnchor.constraint(equalToConstant: 48)
        self.titleLeadingWithIcon = self.articleTitle.leadingAnchor
            .constraint(equalTo: self.iconView.trailingAnchor, constant: 8)
        self.titleLeadingWithoutIcon = self.articleTitle.leadingAnchor
            .constraint(equalTo: self.indicatorView.trailingAnchor, constant: 8)

        NSLayoutConstraint.activate([
            self.indicatorView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            self.indicatorView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            self.indicatorView.widthAnchor.constraint(equalToConstant: 10),
            self.indicatorView.heightAnchor.constraint(equalToConstant: 10),

            self.iconView.leadingAnchor.constraint(equalTo: self.indicatorView.trailingAnchor, constant: 8),
            self.iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            self.iconWidthConstraint!,
            self.iconHeightConstraint!,

            self.articleTitle.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            self.titleLeadingWithIcon!,
            self.articleTitle.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),

            self.articleSummary.topAnchor.constraint(equalTo: self.articleTitle.bottomAnchor, constant: 2),
            self.articleSummary.leadingAnchor.constraint(equalTo: self.articleTitle.leadingAnchor),
            self.articleSummary.trailingAnchor.constraint(equalTo: self.articleTitle.trailingAnchor),

            self.metaDataStackView.topAnchor.constraint(equalTo: self.articleSummary.bottomAnchor, constant: 4),
            self.metaDataStackView.leadingAnchor.constraint(equalTo: self.articleTitle.leadingAnchor),
            self.metaDataStackView.trailingAnchor
                .constraint(lessThanOrEqualTo: contentView.layoutMarginsGuide.trailingAnchor),
            self.metaDataStackView.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),
        ])

        self.configureStackView()
    }

    private func configureStackView() {
        switch traitCollection.preferredContentSizeCategory {
        case .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge, .accessibilityExtraExtraLarge,
             .accessibilityExtraExtraExtraLarge:
            self.metaDataStackView.axis = .vertical
            self.metaDataStackView.alignment = .leading
            self.metaDataStackView.distribution = .fill
        default:
            self.metaDataStackView.axis = .horizontal
            self.metaDataStackView.alignment = .center
            self.metaDataStackView.distribution = .fill
        }
    }

    private func configure(_ cellData: MainTimelineCellData) {
        self.updateIndicatorView(cellData)
        self.articleSummary.numberOfLines = cellData.numberOfLines
        self.applyTitleTextWithAttributes(configurationState)
        self.applySummaryTextWithAttributes(configurationState)

        if cellData.showFeedName == .feed {
            self.authorByLine.text = cellData.feedName
        } else if cellData.showFeedName == .byline {
            self.authorByLine.text = cellData.byline
        } else if cellData.showFeedName == .none {
            self.authorByLine.text = ""
        }

        if cellData.showIcon {
            self.iconView.isHidden = false
            self.titleLeadingWithoutIcon?.isActive = false
            self.titleLeadingWithIcon?.isActive = true
            self.setIconImage(cellData.iconImage, with: cellData.iconSize)
        } else {
            self.iconView.isHidden = true
            self.titleLeadingWithIcon?.isActive = false
            self.titleLeadingWithoutIcon?.isActive = true
        }

        self.articleDate.text = cellData.dateString
    }

    private func setIconImage(_ iconImage: IconImage?, with size: IconSize) {
        self.iconView.iconImage = iconImage
        self.updateIconViewSizeConstraints(to: size.size)
    }

    func setIconImage(_ iconImage: IconImage?) {
        self.iconView.iconImage = iconImage
    }

    private func updateIconViewSizeConstraints(to size: CGSize) {
        self.iconWidthConstraint?.constant = size.width
        self.iconHeightConstraint?.constant = size.height
        setNeedsLayout()
    }

    private func updateIndicatorView(_ cellData: MainTimelineCellData) {
        if cellData.read == false {
            if self.indicatorView.alpha == 0.0 {
                self.indicatorView.alpha = 1.0
            }
            UIView.animate(withDuration: 0.25) {
                self.indicatorView.iconImage = Assets.Images.unreadCellIndicator
                self.indicatorView.tintColor = Assets.Colors.secondaryAccent
            }
            return
        } else if cellData.starred {
            if self.indicatorView.alpha == 0.0 {
                self.indicatorView.alpha = 1.0
            }
            UIView.animate(withDuration: 0.25) {
                self.indicatorView.iconImage = Assets.Images.starredFeed
                self.indicatorView.tintColor = Assets.Colors.star
            }
            return
        } else if self.indicatorView.alpha == 1.0 {
            UIView.animate(withDuration: 0.25) {
                self.indicatorView.alpha = 0.0
                self.indicatorView.iconImage = nil
            }
        }
    }

    private func applyTitleTextWithAttributes(_ state: UICellConfigurationState) {
        let isSelected = state.isSelected || state.isHighlighted || state.isFocused || state.isSwiped
        if self.cellData.title != "" {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.minimumLineHeight = UIFont.preferredFont(forTextStyle: .headline).pointSize
            paragraphStyle.maximumLineHeight = UIFont.preferredFont(forTextStyle: .headline).pointSize
            paragraphStyle.lineBreakMode = .byTruncatingTail
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.preferredFont(forTextStyle: .headline),
                .paragraphStyle: paragraphStyle,
                .foregroundColor: isSelected ? UIColor.white : UIColor.label,
            ]
            self.articleTitle.attributedText = NSAttributedString(
                string: self.cellData.title,
                attributes: titleAttributes
            )
        } else {
            self.articleTitle.attributedText = nil
        }
    }

    private func applySummaryTextWithAttributes(_ state: UICellConfigurationState) {
        let isSelected = state.isSelected || state.isHighlighted || state.isFocused || state.isSwiped
        if self.cellData.summary != "" {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.minimumLineHeight = UIFont.preferredFont(forTextStyle: .body).pointSize
            paragraphStyle.maximumLineHeight = UIFont.preferredFont(forTextStyle: .body).pointSize
            paragraphStyle.lineBreakMode = .byTruncatingTail
            let summaryAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.preferredFont(forTextStyle: .body),
                .paragraphStyle: paragraphStyle,
                .foregroundColor: isSelected ? UIColor.white : UIColor.label,
            ]
            self.articleSummary.attributedText = NSAttributedString(
                string: self.cellData.summary,
                attributes: summaryAttributes
            )
        } else {
            self.articleSummary.attributedText = nil
        }
    }

    override func updateConfiguration(using state: UICellConfigurationState) {
        super.updateConfiguration(using: state)

        var backgroundConfig = UIBackgroundConfiguration.listCell().updated(for: state)
        backgroundConfig.cornerRadius = 20
        if traitCollection.userInterfaceIdiom == .pad {
            backgroundConfig.edgesAddingLayoutMarginsToBackgroundInsets = [.leading, .trailing]
            backgroundConfig.backgroundInsets = NSDirectionalEdgeInsets(
                top: 0,
                leading: -4,
                bottom: 0,
                trailing: -4
            )
        }

        if state.isSelected || state.isHighlighted || state.isFocused || state.isSwiped {
            backgroundConfig.backgroundColor = Assets.Colors.primaryAccent
            self.applyTitleTextWithAttributes(state)
            self.applySummaryTextWithAttributes(state)
            self.articleDate.textColor = .lightText
            self.authorByLine.textColor = .lightText
        } else {
            self.applyTitleTextWithAttributes(state)
            self.applySummaryTextWithAttributes(state)
            self.articleDate.textColor = .secondaryLabel
            self.authorByLine.textColor = .secondaryLabel
        }

        self.backgroundConfiguration = backgroundConfig
    }
}

//
//  AddFeedSelectFolderTableViewCell.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 12/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

final class AddFeedSelectFolderTableViewCell: VibrantTableViewCell {

	let folderLabel: UILabel = {
		let label = UILabel()
		label.font = .preferredFont(forTextStyle: .body)
		label.adjustsFontForContentSizeCategory = true
		label.text = NSLocalizedString("Folder", comment: "Folder")
		label.translatesAutoresizingMaskIntoConstraints = false
		return label
	}()

	let detailLabel: UILabel = {
		let label = UILabel()
		label.font = .preferredFont(forTextStyle: .body)
		label.adjustsFontForContentSizeCategory = true
		label.textColor = .secondaryLabel
		label.textAlignment = .right
		label.translatesAutoresizingMaskIntoConstraints = false
		return label
	}()

	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
		setupViews()
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("Use init(style:reuseIdentifier:)")
	}

	private func setupViews() {
		accessoryType = .disclosureIndicator

		contentView.addSubview(folderLabel)
		contentView.addSubview(detailLabel)

		NSLayoutConstraint.activate([
			folderLabel.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
			folderLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

			detailLabel.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
			detailLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
			detailLabel.leadingAnchor.constraint(greaterThanOrEqualTo: folderLabel.trailingAnchor, constant: 8)
		])

		detailLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
	}

	override func updateVibrancy(animated: Bool) {
		super.updateVibrancy(animated: animated)
		updateLabelVibrancy(folderLabel, color: labelColor, animated: animated)
		updateLabelVibrancy(detailLabel, color: secondaryLabelColor, animated: animated)
	}
}

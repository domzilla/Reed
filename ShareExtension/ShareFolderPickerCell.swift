//
//  ShareFolderPickerCell.swift
//  NetNewsWire iOS Share Extension
//
//  Created by Maurice Parker on 11/16/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

final class ShareFolderPickerCell: UITableViewCell {

	let iconImageView: UIImageView = {
		let imageView = UIImageView()
		imageView.contentMode = .scaleAspectFit
		imageView.translatesAutoresizingMaskIntoConstraints = false
		return imageView
	}()

	let nameLabel: UILabel = {
		let label = UILabel()
		label.font = .preferredFont(forTextStyle: .body)
		label.adjustsFontForContentSizeCategory = true
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

		contentView.addSubview(iconImageView)
		contentView.addSubview(nameLabel)

		NSLayoutConstraint.activate([
			iconImageView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
			iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
			iconImageView.widthAnchor.constraint(equalToConstant: 22),
			iconImageView.heightAnchor.constraint(equalToConstant: 22),

			nameLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
			nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.layoutMarginsGuide.trailingAnchor),
			nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
			nameLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14)
		])

		separatorInset = UIEdgeInsets(top: 0, left: 50, bottom: 0, right: 0)
	}
}

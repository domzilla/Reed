//
//  AddFeedSelectFolderTableViewCell.swift
//  Reed
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
        self.setupViews()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("Use init(style:reuseIdentifier:)")
    }

    private func setupViews() {
        accessoryType = .disclosureIndicator

        contentView.addSubview(self.folderLabel)
        contentView.addSubview(self.detailLabel)

        NSLayoutConstraint.activate([
            self.folderLabel.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            self.folderLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            self.detailLabel.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            self.detailLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            self.detailLabel.leadingAnchor.constraint(
                greaterThanOrEqualTo: self.folderLabel.trailingAnchor,
                constant: 8
            ),
        ])

        self.detailLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
    }

    override func updateVibrancy(animated: Bool) {
        super.updateVibrancy(animated: animated)
        updateLabelVibrancy(self.folderLabel, color: labelColor, animated: animated)
        updateLabelVibrancy(self.detailLabel, color: secondaryLabelColor, animated: animated)
    }
}

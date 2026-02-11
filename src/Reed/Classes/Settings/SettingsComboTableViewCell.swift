//
//  SettingsComboTableViewCell.swift
//  Reed
//
//  Created by Maurice Parker on 10/23/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

final class SettingsComboTableViewCell: VibrantTableViewCell {
    let comboImage: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    let comboNameLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
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

        contentView.addSubview(self.comboImage)
        contentView.addSubview(self.comboNameLabel)

        NSLayoutConstraint.activate([
            self.comboImage.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            self.comboImage.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            self.comboImage.widthAnchor.constraint(equalToConstant: 24),
            self.comboImage.heightAnchor.constraint(equalToConstant: 24),

            self.comboNameLabel.leadingAnchor.constraint(equalTo: self.comboImage.trailingAnchor, constant: 12),
            self.comboNameLabel.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            self.comboNameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }

    override func updateVibrancy(animated: Bool) {
        super.updateVibrancy(animated: animated)
        updateLabelVibrancy(self.comboNameLabel, color: labelColor, animated: animated)

        let tintColor = isHighlighted || isSelected ? Assets.Colors.vibrantText : UIColor.label
        if animated {
            UIView.animate(withDuration: Self.duration) {
                self.comboImage.tintColor = tintColor
            }
        } else {
            self.comboImage.tintColor = tintColor
        }
    }
}

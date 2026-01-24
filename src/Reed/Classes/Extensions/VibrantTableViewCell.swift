//
//  VibrantTableViewCell.swift
//  NetNewsWire-iOS
//
//  Created by Jim Correia on 9/2/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

class VibrantTableViewCell: UITableViewCell {
    static let duration: TimeInterval = 0.6

    var labelColor: UIColor {
        isHighlighted || isSelected ? Assets.Colors.vibrantText : UIColor.label
    }

    var secondaryLabelColor: UIColor {
        isHighlighted || isSelected ? Assets.Colors.vibrantText : UIColor.secondaryLabel
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.commonInit()
    }

    private func commonInit() {
        self.applyThemeProperties()
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        self.updateVibrancy(animated: animated)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        self.updateVibrancy(animated: animated)
    }

    /// Subclass overrides should call super
    func applyThemeProperties() {
        let selectedBackgroundView = UIView(frame: .zero)
        selectedBackgroundView.backgroundColor = Assets.Colors.secondaryAccent
        self.selectedBackgroundView = selectedBackgroundView
    }

    /// Subclass overrides should call super
    func updateVibrancy(animated: Bool) {
        self.updateLabelVibrancy(textLabel, color: self.labelColor, animated: animated)
        self.updateLabelVibrancy(detailTextLabel, color: self.labelColor, animated: animated)
    }

    func updateLabelVibrancy(_ label: UILabel?, color: UIColor, animated: Bool) {
        guard let label else { return }
        if animated {
            UIView.transition(with: label, duration: Self.duration, options: .transitionCrossDissolve, animations: {
                label.textColor = color
            }, completion: nil)
        } else {
            label.textColor = color
        }
    }
}

class VibrantBasicTableViewCell: VibrantTableViewCell {
    let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
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

    var imageNormal: UIImage?
    var imageSelected: UIImage?

    var iconTint: UIColor {
        isHighlighted || isSelected ? labelColor : Assets.Colors.primaryAccent
    }

    var iconImage: UIImage? {
        isHighlighted || isSelected ? self.imageSelected : self.imageNormal
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setupViews()
    }

    private func setupViews() {
        contentView.addSubview(self.iconImageView)
        contentView.addSubview(self.titleLabel)
        contentView.addSubview(self.detailLabel)

        NSLayoutConstraint.activate([
            self.iconImageView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            self.iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            self.iconImageView.widthAnchor.constraint(equalToConstant: 24),
            self.iconImageView.heightAnchor.constraint(equalToConstant: 24),

            self.titleLabel.leadingAnchor.constraint(equalTo: self.iconImageView.trailingAnchor, constant: 12),
            self.titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            self.detailLabel.leadingAnchor.constraint(
                greaterThanOrEqualTo: self.titleLabel.trailingAnchor,
                constant: 8
            ),
            self.detailLabel.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            self.detailLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])

        self.detailLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
    }

    override func updateVibrancy(animated: Bool) {
        super.updateVibrancy(animated: animated)
        self.updateIconVibrancy(self.iconImageView, color: self.iconTint, image: self.iconImage, animated: animated)
        updateLabelVibrancy(self.titleLabel, color: labelColor, animated: animated)
        updateLabelVibrancy(self.detailLabel, color: secondaryLabelColor, animated: animated)
    }

    private func updateIconVibrancy(_ icon: UIImageView, color: UIColor, image: UIImage?, animated: Bool) {
        if animated {
            UIView.transition(with: icon, duration: Self.duration, options: .transitionCrossDissolve, animations: {
                icon.tintColor = color
                icon.image = image
            }, completion: nil)
        } else {
            icon.tintColor = color
            icon.image = image
        }
    }
}

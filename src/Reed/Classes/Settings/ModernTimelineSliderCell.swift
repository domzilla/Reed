//
//  ModernTimelineSliderCell.swift
//  Reed
//
//  Created by Stuart Breckenridge on 21/08/2025.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import UIKit

enum SliderConfiguration {
    case numberOfLines
    case iconSize
}

final class ModernTimelineSliderCell: UITableViewCell {
    let slider: UISlider = {
        let slider = UISlider()
        slider.translatesAutoresizingMaskIntoConstraints = false
        return slider
    }()

    private let container = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("Use init(style:reuseIdentifier:)")
    }

    private func setup() {
        self.container.layer.cornerRadius = 22
        self.container.backgroundColor = .systemBackground
        self.container.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(self.container)
        contentView.sendSubviewToBack(self.container)

        contentView.addSubview(self.slider)
        self.slider.addTarget(self, action: #selector(self.sliderValueChanges(_:)), for: .valueChanged)

        NSLayoutConstraint.activate([
            self.container.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 0),
            self.container.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: 0),
            self.container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            self.container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            self.slider.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            self.slider.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),
            self.slider.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
        contentView.backgroundColor = .systemGroupedBackground
    }

    var sliderConfiguration: SliderConfiguration! {
        didSet {
            switch self.sliderConfiguration {
            case .numberOfLines:
                self.slider.minimumValue = 1
                self.slider.maximumValue = 6
                self.slider.trackConfiguration = .init(allowsTickValuesOnly: true, numberOfTicks: 6)
                self.slider.value = Float(AppDefaults.shared.timelineNumberOfLines)
            case .iconSize:
                self.slider.minimumValue = 1
                self.slider.maximumValue = 3
                self.slider.trackConfiguration = .init(allowsTickValuesOnly: true, numberOfTicks: 3)
                self.slider.value = Float(AppDefaults.shared.timelineIconSize.rawValue)
            case .none:
                return
            }
        }
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    @objc
    func sliderValueChanges(_: Any) {
        switch self.sliderConfiguration {
        case .numberOfLines:
            AppDefaults.shared.timelineNumberOfLines = Int(self.slider.value.rounded())
        case .iconSize:
            guard let iconSize = IconSize(rawValue: Int(slider.value.rounded())) else { return }
            AppDefaults.shared.timelineIconSize = iconSize
        case .none:
            return
        }
    }
}

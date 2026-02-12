//
//  RefreshProgressView.swift
//  Reed
//
//  Created by Maurice Parker on 10/24/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

final class RefreshProgressView: UIView {
    let progressView: UIProgressView = {
        let view = UIProgressView(progressViewStyle: .default)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    let label: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setupViews()
    }

    private func setupViews() {
        addSubview(self.progressView)
        addSubview(self.label)

        NSLayoutConstraint.activate([
            self.progressView.leadingAnchor.constraint(equalTo: leadingAnchor),
            self.progressView.trailingAnchor.constraint(equalTo: trailingAnchor),
            self.progressView.centerYAnchor.constraint(equalTo: centerYAnchor),

            self.label.leadingAnchor.constraint(equalTo: leadingAnchor),
            self.label.trailingAnchor.constraint(equalTo: trailingAnchor),
            self.label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.progressDidChange(_:)),
            name: .combinedRefreshProgressDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.contentSizeCategoryDidChange(_:)),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )
        self.update()
        scheduleUpdateRefreshLabel()

        isAccessibilityElement = true
        accessibilityTraits = [.updatesFrequently, .notEnabled]
    }

    func update() {
        if !DataStoreManager.shared.combinedRefreshProgress.isComplete {
            progressChanged(animated: false)
        } else {
            updateRefreshLabel()
        }
    }

    override func didMoveToSuperview() {
        progressChanged(animated: false)
    }

    @objc
    func progressDidChange(_: Notification) {
        progressChanged(animated: true)
    }

    @objc
    func contentSizeCategoryDidChange(_: Notification) {
        // This hack is probably necessary because custom views in the toolbar don't get
        // notifications that the content size changed.
        self.label.font = UIFont.preferredFont(forTextStyle: .footnote)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: Private

extension RefreshProgressView {
    private func progressChanged(animated: Bool) {
        // Layout may crash if not in the view hierarchy.
        // https://github.com/Ranchero-Software/NetNewsWire/issues/1764
        let isInViewHierarchy = self.superview != nil

        let progress = DataStoreManager.shared.combinedRefreshProgress

        if progress.isComplete {
            if isInViewHierarchy {
                self.progressView.setProgress(1, animated: animated)
            }

            func completeLabel() {
                // Check that there are no pending downloads.
                if DataStoreManager.shared.combinedRefreshProgress.isComplete {
                    self.updateRefreshLabel()
                    self.label.isHidden = false
                    self.progressView.isHidden = true
                    if self.superview != nil {
                        self.progressView.setProgress(0, animated: animated)
                    }
                }
            }

            if animated {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    completeLabel()
                }
            } else {
                completeLabel()
            }
        } else {
            self.label.isHidden = true
            self.progressView.isHidden = false
            if isInViewHierarchy {
                let percent = Float(progress.numberCompleted) / Float(progress.numberOfTasks)

                // Don't let the progress bar go backwards unless we need to go back more than 25%
                if percent > self.progressView.progress || self.progressView.progress - percent > 0.25 {
                    self.progressView.setProgress(percent, animated: animated)
                }
            }
        }
    }

    private func updateRefreshLabel() {
        if let lastArticleFetchEndTime = DataStoreManager.shared.lastArticleFetchEndTime {
            if Date() > lastArticleFetchEndTime.addingTimeInterval(60) {
                let relativeDateTimeFormatter = RelativeDateTimeFormatter()
                relativeDateTimeFormatter.dateTimeStyle = .named
                let refreshed = relativeDateTimeFormatter.localizedString(
                    for: lastArticleFetchEndTime,
                    relativeTo: Date()
                )
                let localizedRefreshText = NSLocalizedString("Updated %@", comment: "Updated")
                let refreshText = NSString.localizedStringWithFormat(
                    localizedRefreshText as NSString,
                    refreshed
                ) as String
                self.label.text = refreshText

            } else {
                self.label.text = NSLocalizedString("Updated Just Now", comment: "Updated Just Now")
            }

        } else {
            self.label.text = ""
        }

        accessibilityLabel = self.label.text
    }

    private func scheduleUpdateRefreshLabel() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
            self?.updateRefreshLabel()
            self?.scheduleUpdateRefreshLabel()
        }
    }
}

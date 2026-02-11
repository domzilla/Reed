//
//  ImageViewController.swift
//  Reed
//
//  Created by Maurice Parker on 10/12/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

final class ImageViewController: UIViewController {
    var image: UIImage!
    var imageTitle: String?
    var zoomedFrame: CGRect {
        self.imageScrollView.zoomedFrame
    }

    // MARK: - UI Elements

    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        button.setImage(UIImage(systemName: "xmark.circle.fill", withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.imageView?.contentMode = .scaleAspectFit
        button.accessibilityLabel = NSLocalizedString("Close", comment: "Close")
        button.addTarget(self, action: #selector(self.done(_:)), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var shareButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        button.setImage(UIImage(systemName: "square.and.arrow.up", withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.accessibilityLabel = NSLocalizedString("Share", comment: "Share")
        button.addTarget(self, action: #selector(self.share(_:)), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var imageScrollView: ImageScrollView = {
        let scrollView = ImageScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .white
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var titleBackground: UIVisualEffectView = {
        let effect = UIBlurEffect(style: .dark)
        let view = UIVisualEffectView(effect: effect)
        view.layer.cornerRadius = 6
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private var titleLeadingConstraint: NSLayoutConstraint!
    private var titleTrailingConstraint: NSLayoutConstraint!

    // MARK: - Initialization

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("Use init()")
    }

    // MARK: - Lifecycle

    override var keyCommands: [UIKeyCommand]? {
        [
            UIKeyCommand(
                title: NSLocalizedString("Close Image", comment: "Close Image"),
                action: #selector(self.done(_:)),
                input: " "
            ),
        ]
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black

        view.addSubview(self.imageScrollView)
        view.addSubview(self.closeButton)
        view.addSubview(self.shareButton)

        NSLayoutConstraint.activate([
            self.imageScrollView.topAnchor.constraint(equalTo: view.topAnchor),
            self.imageScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            self.imageScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            self.imageScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            self.closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            self.closeButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            self.closeButton.widthAnchor.constraint(equalToConstant: 44),
            self.closeButton.heightAnchor.constraint(equalToConstant: 44),

            self.shareButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            self.shareButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            self.shareButton.widthAnchor.constraint(equalToConstant: 44),
            self.shareButton.heightAnchor.constraint(equalToConstant: 44),
        ])

        self.imageScrollView.setup()
        self.imageScrollView.imageScrollViewDelegate = self
        self.imageScrollView.imageContentMode = .aspectFit
        self.imageScrollView.initialOffset = .center
        self.imageScrollView.display(image: self.image)

        self.titleLabel.text = imageTitle ?? ""

        guard let imageTitle, !imageTitle.isEmpty else {
            return
        }

        // Add title background and label only if there's a title
        view.addSubview(self.titleBackground)
        self.titleBackground.contentView.addSubview(self.titleLabel)

        let multiplier = traitCollection.userInterfaceIdiom == .pad ? CGFloat(0.1) : CGFloat(0.04)
        let leadingInset = view.frame.width * multiplier

        self.titleLeadingConstraint = self.titleBackground.leadingAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.leadingAnchor,
            constant: leadingInset + 16
        )
        self.titleTrailingConstraint = self.titleBackground.trailingAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.trailingAnchor,
            constant: -(leadingInset + 16)
        )

        NSLayoutConstraint.activate([
            self.titleBackground.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            self.titleLeadingConstraint,
            self.titleTrailingConstraint,

            self.titleLabel.topAnchor.constraint(equalTo: self.titleBackground.contentView.topAnchor, constant: 8),
            self.titleLabel.bottomAnchor.constraint(
                equalTo: self.titleBackground.contentView.bottomAnchor,
                constant: -8
            ),
            self.titleLabel.leadingAnchor.constraint(
                equalTo: self.titleBackground.contentView.leadingAnchor,
                constant: 12
            ),
            self.titleLabel.trailingAnchor.constraint(
                equalTo: self.titleBackground.contentView.trailingAnchor,
                constant: -12
            ),
        ])
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.imageScrollView.resize()
        })
    }

    // MARK: - Actions

    @objc
    func share(_: Any) {
        guard let image else { return }
        let activityViewController = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        activityViewController.popoverPresentationController?.sourceView = self.shareButton
        activityViewController.popoverPresentationController?.sourceRect = self.shareButton.bounds
        present(activityViewController, animated: true)
    }

    @objc
    func done(_: Any) {
        dismiss(animated: true)
    }
}

// MARK: ImageScrollViewDelegate

extension ImageViewController: ImageScrollViewDelegate {
    func imageScrollViewDidGestureSwipeUp(imageScrollView _: ImageScrollView) {
        dismiss(animated: true)
    }

    func imageScrollViewDidGestureSwipeDown(imageScrollView _: ImageScrollView) {
        dismiss(animated: true)
    }
}

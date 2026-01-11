//
//  ImageViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 10/12/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

final class ImageViewController: UIViewController {

	var image: UIImage!
	var imageTitle: String?
	var zoomedFrame: CGRect {
		return imageScrollView.zoomedFrame
	}

	// MARK: - UI Elements

	private lazy var closeButton: UIButton = {
		let button = UIButton(type: .system)
		let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
		button.setImage(UIImage(systemName: "xmark.circle.fill", withConfiguration: config), for: .normal)
		button.tintColor = .white
		button.imageView?.contentMode = .scaleAspectFit
		button.accessibilityLabel = NSLocalizedString("Close", comment: "Close")
		button.addTarget(self, action: #selector(done(_:)), for: .touchUpInside)
		button.translatesAutoresizingMaskIntoConstraints = false
		return button
	}()

	private lazy var shareButton: UIButton = {
		let button = UIButton(type: .system)
		let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
		button.setImage(UIImage(systemName: "square.and.arrow.up", withConfiguration: config), for: .normal)
		button.tintColor = .white
		button.accessibilityLabel = NSLocalizedString("Share", comment: "Share")
		button.addTarget(self, action: #selector(share(_:)), for: .touchUpInside)
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
	required init?(coder: NSCoder) {
		fatalError("Use init()")
	}

	// MARK: - Lifecycle

	override var keyCommands: [UIKeyCommand]? {
		return [
			UIKeyCommand(
				title: NSLocalizedString("Close Image", comment: "Close Image"),
				action: #selector(done(_:)),
				input: " "
			)
		]
	}

	override func viewDidLoad() {
        super.viewDidLoad()

		view.backgroundColor = .black

		view.addSubview(imageScrollView)
		view.addSubview(closeButton)
		view.addSubview(shareButton)

		NSLayoutConstraint.activate([
			imageScrollView.topAnchor.constraint(equalTo: view.topAnchor),
			imageScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
			imageScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			imageScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

			closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
			closeButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
			closeButton.widthAnchor.constraint(equalToConstant: 44),
			closeButton.heightAnchor.constraint(equalToConstant: 44),

			shareButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
			shareButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
			shareButton.widthAnchor.constraint(equalToConstant: 44),
			shareButton.heightAnchor.constraint(equalToConstant: 44),
		])

        imageScrollView.setup()
        imageScrollView.imageScrollViewDelegate = self
        imageScrollView.imageContentMode = .aspectFit
        imageScrollView.initialOffset = .center
		imageScrollView.display(image: image)

		titleLabel.text = imageTitle ?? ""

		guard let imageTitle = imageTitle, !imageTitle.isEmpty else {
			return
		}

		// Add title background and label only if there's a title
		view.addSubview(titleBackground)
		titleBackground.contentView.addSubview(titleLabel)

		let multiplier = traitCollection.userInterfaceIdiom == .pad ? CGFloat(0.1) : CGFloat(0.04)
		let leadingInset = view.frame.width * multiplier

		titleLeadingConstraint = titleBackground.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: leadingInset + 16)
		titleTrailingConstraint = titleBackground.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -(leadingInset + 16))

		NSLayoutConstraint.activate([
			titleBackground.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
			titleLeadingConstraint,
			titleTrailingConstraint,

			titleLabel.topAnchor.constraint(equalTo: titleBackground.contentView.topAnchor, constant: 8),
			titleLabel.bottomAnchor.constraint(equalTo: titleBackground.contentView.bottomAnchor, constant: -8),
			titleLabel.leadingAnchor.constraint(equalTo: titleBackground.contentView.leadingAnchor, constant: 12),
			titleLabel.trailingAnchor.constraint(equalTo: titleBackground.contentView.trailingAnchor, constant: -12),
		])
    }

	override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		super.viewWillTransition(to: size, with: coordinator)
		coordinator.animate(alongsideTransition: { [weak self] context in
			self?.imageScrollView.resize()
		})
	}

	// MARK: - Actions

	@objc func share(_ sender: Any) {
		guard let image = image else { return }
		let activityViewController = UIActivityViewController(activityItems: [image], applicationActivities: nil)
		activityViewController.popoverPresentationController?.sourceView = shareButton
		activityViewController.popoverPresentationController?.sourceRect = shareButton.bounds
		present(activityViewController, animated: true)
	}

	@objc func done(_ sender: Any) {
		dismiss(animated: true)
	}
}

// MARK: ImageScrollViewDelegate

extension ImageViewController: ImageScrollViewDelegate {

	func imageScrollViewDidGestureSwipeUp(imageScrollView: ImageScrollView) {
		dismiss(animated: true)
	}

	func imageScrollViewDidGestureSwipeDown(imageScrollView: ImageScrollView) {
		dismiss(animated: true)
	}


}

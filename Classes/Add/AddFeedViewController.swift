//
//  AddFeedViewController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/16/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import UIKit
import RSCore
import RSTree
import RSParser

final class AddFeedViewController: UITableViewController {

	static let preferredContentSizeForFormSheetDisplay = CGSize(width: 460.0, height: 400.0)

	private var folderLabel = ""
	private var userCancelled = false

	private let activityIndicator = UIActivityIndicatorView(style: .medium)

	var initialFeed: String?
	var initialFeedName: String?

	var container: Container?

	// MARK: - UI Elements

	private lazy var addButton: UIBarButtonItem = {
		let button = UIBarButtonItem(title: NSLocalizedString("Add", comment: "Add"), style: .prominent, target: self, action: #selector(add(_:)))
		button.isEnabled = false
		return button
	}()

	private lazy var urlTextField: UITextField = {
		let textField = UITextField()
		textField.placeholder = NSLocalizedString("URL", comment: "URL")
		textField.autocorrectionType = .no
		textField.autocapitalizationType = .none
		textField.keyboardType = .URL
		textField.returnKeyType = .done
		textField.clearButtonMode = .whileEditing
		textField.font = .preferredFont(forTextStyle: .body)
		textField.adjustsFontForContentSizeCategory = true
		textField.translatesAutoresizingMaskIntoConstraints = false
		return textField
	}()

	private lazy var nameTextField: UITextField = {
		let textField = UITextField()
		textField.placeholder = NSLocalizedString("Title (Optional)", comment: "Title (Optional)")
		textField.autocorrectionType = .no
		textField.autocapitalizationType = .words
		textField.returnKeyType = .done
		textField.clearButtonMode = .whileEditing
		textField.font = .preferredFont(forTextStyle: .body)
		textField.adjustsFontForContentSizeCategory = true
		textField.translatesAutoresizingMaskIntoConstraints = false
		return textField
	}()

	// MARK: - Initialization

	init() {
		super.init(style: .insetGrouped)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("Use init()")
	}

	// MARK: - Lifecycle

	override func viewDidLoad() {
        super.viewDidLoad()

		title = NSLocalizedString("Add Web Feed", comment: "Add Web Feed")
		// Use text "Cancel" button to match storyboard (not X icon)
		navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .plain, target: self, action: #selector(cancel(_:)))
		navigationItem.rightBarButtonItem = addButton

		if initialFeed == nil, let urlString = UIPasteboard.general.string {
			if urlString.mayBeURL {
				initialFeed = urlString.normalizedURL
			}
		}

		urlTextField.text = initialFeed
		urlTextField.delegate = self

		if initialFeed != nil {
			addButton.isEnabled = true
		}

		nameTextField.text = initialFeedName
		nameTextField.delegate = self

		if let defaultContainer = AddFeedDefaultContainer.defaultContainer {
			container = defaultContainer
		} else {
			addButton.isEnabled = false
		}

		updateFolderLabel()

		tableView.register(UITableViewCell.self, forCellReuseIdentifier: "TextFieldCell")
		tableView.register(AddFeedSelectFolderTableViewCell.self, forCellReuseIdentifier: "AddFeedSelectFolderTableViewCell")

		NotificationCenter.default.addObserver(self, selector: #selector(textDidChange(_:)), name: UITextField.textDidChangeNotification, object: urlTextField)

		if initialFeed == nil {
			urlTextField.becomeFirstResponder()
		}
	}

	// MARK: - Actions

	@objc func cancel(_ sender: Any) {
		userCancelled = true
		dismiss(animated: true)
	}

	@objc func add(_ sender: Any) {

		let urlString = urlTextField.text ?? ""
		let normalizedURLString = urlString.normalizedURL

		guard !normalizedURLString.isEmpty, let url = URL(string: normalizedURLString) else {
			return
		}

		guard let container = container else { return }

		var account: Account?
		if let containerAccount = container as? Account {
			account = containerAccount
		} else if let containerFolder = container as? Folder, let containerAccount = containerFolder.account {
			account = containerAccount
		}

		if account!.hasFeed(withURL: url.absoluteString) {
			presentError(AccountError.createErrorAlreadySubscribed)
 			return
		}

		addButton.isEnabled = false
		navigationItem.rightBarButtonItem?.customView = activityIndicator
		navigationItem.rightBarButtonItem?.customView?.isHidden = false
		activityIndicator.startAnimating()

		let feedName = (nameTextField.text?.isEmpty ?? true) ? nil : nameTextField.text

		BatchUpdate.shared.start()

		account!.createFeed(url: url.absoluteString, name: feedName, container: container, validateFeed: true) { result in

			BatchUpdate.shared.end()

			switch result {
			case .success(let feed):
				self.dismiss(animated: true)
				NotificationCenter.default.post(name: .UserDidAddFeed, object: self, userInfo: [UserInfoKey.feed: feed])
			case .failure(let error):
				self.addButton.isEnabled = true
				self.activityIndicator.stopAnimating()
				self.navigationItem.rightBarButtonItem?.customView = nil
				self.presentError(error)
			}

		}

	}

	@objc func textDidChange(_ note: Notification) {
		updateUI()
	}

	// MARK: - Table view data source

	override func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return 3
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		switch indexPath.row {
		case 0:
			let cell = tableView.dequeueReusableCell(withIdentifier: "TextFieldCell", for: indexPath)
			cell.contentView.subviews.forEach { $0.removeFromSuperview() }
			cell.selectionStyle = .none
			cell.contentView.addSubview(urlTextField)
			NSLayoutConstraint.activate([
				urlTextField.leadingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.leadingAnchor),
				urlTextField.trailingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor),
				urlTextField.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 11),
				urlTextField.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -11)
			])
			return cell
		case 1:
			let cell = tableView.dequeueReusableCell(withIdentifier: "TextFieldCell", for: indexPath)
			cell.contentView.subviews.forEach { $0.removeFromSuperview() }
			cell.selectionStyle = .none
			cell.contentView.addSubview(nameTextField)
			NSLayoutConstraint.activate([
				nameTextField.leadingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.leadingAnchor),
				nameTextField.trailingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor),
				nameTextField.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 11),
				nameTextField.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -11)
			])
			return cell
		case 2:
			let cell = tableView.dequeueReusableCell(withIdentifier: "AddFeedSelectFolderTableViewCell", for: indexPath) as! AddFeedSelectFolderTableViewCell
			cell.detailLabel.text = folderLabel
			// No chevron to match storyboard
			cell.accessoryType = .none
			return cell
		default:
			fatalError("Unexpected row")
		}
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		if indexPath.row == 2 {
			let folderViewController = AddFeedFolderViewController()
			let navController = UINavigationController(rootViewController: folderViewController)
			navController.modalPresentationStyle = .currentContext
			folderViewController.delegate = self
			folderViewController.initialContainer = container
			present(navController, animated: true)
		}
	}

}

// MARK: AddFeedFolderViewControllerDelegate

extension AddFeedViewController: AddFeedFolderViewControllerDelegate {
	func didSelect(container: Container) {
		self.container = container
		updateFolderLabel()
		AddFeedDefaultContainer.saveDefaultContainer(container)
	}
}

// MARK: UITextFieldDelegate

extension AddFeedViewController: UITextFieldDelegate {

	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.resignFirstResponder()
		return true
	}

}

// MARK: Private

private extension AddFeedViewController {

	func updateUI() {
		addButton.isEnabled = (urlTextField.text?.mayBeURL ?? false)
	}

	func updateFolderLabel() {
		if let containerName = (container as? DisplayNameProvider)?.nameForDisplay {
			if container is Folder {
				folderLabel = "\(container?.account?.nameForDisplay ?? "") / \(containerName)"
			} else {
				folderLabel = containerName
			}
			tableView.reloadData()
		}
	}
}

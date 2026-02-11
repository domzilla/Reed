//
//  AddFeedViewController.swift
//  Reed
//
//  Created by Maurice Parker on 4/16/19.
//  Copyright © 2019 Ranchero Software, LLC. All rights reserved.
//

import RSCore
import RSParser
import RSTree
import UIKit

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
        let button = UIBarButtonItem(
            title: NSLocalizedString("Add", comment: "Add"),
            style: .prominent,
            target: self,
            action: #selector(add(_:))
        )
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
    required init?(coder _: NSCoder) {
        fatalError("Use init()")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("Add Web Feed", comment: "Add Web Feed")
        // Use text "Cancel" button to match storyboard (not X icon)
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: NSLocalizedString("Cancel", comment: "Cancel"),
            style: .plain,
            target: self,
            action: #selector(self.cancel(_:))
        )
        navigationItem.rightBarButtonItem = self.addButton

        if self.initialFeed == nil, let urlString = UIPasteboard.general.string {
            if urlString.mayBeURL {
                self.initialFeed = urlString.normalizedURL
            }
        }

        self.urlTextField.text = self.initialFeed
        self.urlTextField.delegate = self

        if self.initialFeed != nil {
            self.addButton.isEnabled = true
        }

        self.nameTextField.text = self.initialFeedName
        self.nameTextField.delegate = self

        if let defaultContainer = AddFeedDefaultContainer.defaultContainer {
            self.container = defaultContainer
        } else {
            self.addButton.isEnabled = false
        }

        updateFolderLabel()

        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "TextFieldCell")
        self.tableView.register(
            AddFeedSelectFolderTableViewCell.self,
            forCellReuseIdentifier: "AddFeedSelectFolderTableViewCell"
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.textDidChange(_:)),
            name: UITextField.textDidChangeNotification,
            object: self.urlTextField
        )

        if self.initialFeed == nil {
            self.urlTextField.becomeFirstResponder()
        }
    }

    // MARK: - Actions

    @objc
    func cancel(_: Any) {
        self.userCancelled = true
        dismiss(animated: true)
    }

    @objc
    func add(_: Any) {
        let urlString = self.urlTextField.text ?? ""
        let normalizedURLString = urlString.normalizedURL

        guard !normalizedURLString.isEmpty, let url = URL(string: normalizedURLString) else {
            return
        }

        guard let container else { return }

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

        self.addButton.isEnabled = false
        navigationItem.rightBarButtonItem?.customView = self.activityIndicator
        navigationItem.rightBarButtonItem?.customView?.isHidden = false
        self.activityIndicator.startAnimating()

        let feedName = (nameTextField.text?.isEmpty ?? true) ? nil : self.nameTextField.text

        BatchUpdate.shared.start()

        account!
            .createFeed(url: url.absoluteString, name: feedName, container: container, validateFeed: true) { result in
                BatchUpdate.shared.end()

                switch result {
                case let .success(feed):
                    self.dismiss(animated: true)
                    NotificationCenter.default.post(
                        name: .UserDidAddFeed,
                        object: self,
                        userInfo: [UserInfoKey.feed: feed]
                    )
                case let .failure(error):
                    self.addButton.isEnabled = true
                    self.activityIndicator.stopAnimating()
                    self.navigationItem.rightBarButtonItem?.customView = nil
                    self.presentError(error)
                }
            }
    }

    @objc
    func textDidChange(_: Notification) {
        updateUI()
    }

    // MARK: - Table view data source

    override func numberOfSections(in _: UITableView) -> Int {
        1
    }

    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        3
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.row {
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: "TextFieldCell", for: indexPath)
            cell.contentView.subviews.forEach { $0.removeFromSuperview() }
            cell.selectionStyle = .none
            cell.contentView.addSubview(self.urlTextField)
            NSLayoutConstraint.activate([
                self.urlTextField.leadingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.leadingAnchor),
                self.urlTextField.trailingAnchor
                    .constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor),
                self.urlTextField.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 11),
                self.urlTextField.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -11),
            ])
            return cell
        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: "TextFieldCell", for: indexPath)
            cell.contentView.subviews.forEach { $0.removeFromSuperview() }
            cell.selectionStyle = .none
            cell.contentView.addSubview(self.nameTextField)
            NSLayoutConstraint.activate([
                self.nameTextField.leadingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.leadingAnchor),
                self.nameTextField.trailingAnchor
                    .constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor),
                self.nameTextField.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 11),
                self.nameTextField.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -11),
            ])
            return cell
        case 2:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: "AddFeedSelectFolderTableViewCell",
                for: indexPath
            ) as! AddFeedSelectFolderTableViewCell
            cell.detailLabel.text = self.folderLabel
            // No chevron to match storyboard
            cell.accessoryType = .none
            return cell
        default:
            fatalError("Unexpected row")
        }
    }

    override func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 2 {
            let folderViewController = AddFeedFolderViewController()
            let navController = UINavigationController(rootViewController: folderViewController)
            navController.modalPresentationStyle = .currentContext
            folderViewController.delegate = self
            folderViewController.initialContainer = self.container
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

extension AddFeedViewController {
    private func updateUI() {
        self.addButton.isEnabled = (self.urlTextField.text?.mayBeURL ?? false)
    }

    private func updateFolderLabel() {
        if let containerName = (container as? DisplayNameProvider)?.nameForDisplay {
            if self.container is Folder {
                self.folderLabel = "\(self.container?.account?.nameForDisplay ?? "") / \(containerName)"
            } else {
                self.folderLabel = containerName
            }
            self.tableView.reloadData()
        }
    }
}

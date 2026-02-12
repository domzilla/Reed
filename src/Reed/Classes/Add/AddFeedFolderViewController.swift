//
//  AddFeedFolderViewController.swift
//  Reed
//
//  Created by Maurice Parker on 11/16/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

@MainActor
protocol AddFeedFolderViewControllerDelegate {
    func didSelect(container: Container)
}

final class AddFeedFolderViewController: UITableViewController {
    var delegate: AddFeedFolderViewControllerDelegate?
    var initialContainer: Container?

    var containers = [Container]()

    // MARK: - Initialization

    init() {
        // Use .grouped to match storyboard (plain list style, not insetGrouped card style)
        super.init(style: .grouped)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("Use init()")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("Select Folder", comment: "Select Folder")
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(self.cancel(_:))
        )

        self.tableView.register(AddComboTableViewCell.self, forCellReuseIdentifier: "AccountCell")
        self.tableView.register(AddComboTableViewCell.self, forCellReuseIdentifier: "FolderCell")

        let sortedActiveDataStores = DataStore.shared.sortedActiveDataStores

        for dataStore in sortedActiveDataStores {
            self.containers.append(dataStore)
            if let sortedFolders = dataStore.sortedFolders {
                self.containers.append(contentsOf: sortedFolders)
            }
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in _: UITableView) -> Int {
        1
    }

    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        self.containers.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let container = self.containers[indexPath.row]
        let cell: AddComboTableViewCell = if container is DataStore {
            tableView.dequeueReusableCell(withIdentifier: "AccountCell", for: indexPath) as! AddComboTableViewCell
        } else {
            tableView.dequeueReusableCell(withIdentifier: "FolderCell", for: indexPath) as! AddComboTableViewCell
        }

        if let smallIconProvider = container as? SmallIconProvider {
            cell.iconImageView.image = smallIconProvider.smallIcon?.image
        }

        if let displayNameProvider = container as? DisplayNameProvider {
            cell.nameLabel.text = displayNameProvider.nameForDisplay
        }

        if let compContainer = initialContainer, container === compContainer {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let container = self.containers[indexPath.row]

        let cell = tableView.cellForRow(at: indexPath)
        cell?.accessoryType = .checkmark
        self.delegate?.didSelect(container: container)
        dismissViewController()
    }

    // MARK: Actions

    @objc
    func cancel(_: Any) {
        dismissViewController()
    }
}

extension AddFeedFolderViewController {
    private func dismissViewController() {
        dismiss(animated: true)
    }
}

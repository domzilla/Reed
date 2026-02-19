//
//  MainFeedCollectionViewController+ContextMenus.swift
//  Reed
//
//  Created by Dominic Rodemer on 12/02/2026.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import UIKit

// MARK: - Context Menu Builders

extension MainFeedCollectionViewController {
    func makeFeedContextMenu(indexPath: IndexPath, includeDeleteRename: Bool) -> UIContextMenuConfiguration {
        UIContextMenuConfiguration(
            identifier: MainFeedRowIdentifier(indexPath: indexPath),
            previewProvider: nil,
            actionProvider: { [weak self] _ in
                guard let self else { return nil }

                var menuElements = [UIMenuElement]()

                if let inspectorAction = self.getInfoAction(indexPath: indexPath) {
                    menuElements.append(UIMenu(title: "", options: .displayInline, children: [inspectorAction]))
                }

                if let markAllAction = self.markAllAsReadAction(indexPath: indexPath) {
                    menuElements.append(UIMenu(title: "", options: .displayInline, children: [markAllAction]))
                }

                if let moveAction = self.moveToFolderAction(indexPath: indexPath) {
                    menuElements.append(UIMenu(title: "", options: .displayInline, children: [moveAction]))
                }

                if includeDeleteRename {
                    menuElements.append(UIMenu(
                        title: "",
                        options: .displayInline,
                        children: [
                            self.renameAction(indexPath: indexPath),
                            self.deleteAction(indexPath: indexPath),
                        ]
                    ))
                }

                return UIMenu(title: "", children: menuElements)
            }
        )
    }

    func makeFolderContextMenu(indexPath: IndexPath) -> UIContextMenuConfiguration {
        UIContextMenuConfiguration(
            identifier: MainFeedRowIdentifier(indexPath: indexPath),
            previewProvider: nil,
            actionProvider: { [weak self] _ in
                guard let self else { return nil }

                var menuElements = [UIMenuElement]()

                if let markAllAction = self.markAllAsReadAction(indexPath: indexPath) {
                    menuElements.append(UIMenu(title: "", options: .displayInline, children: [markAllAction]))
                }

                menuElements.append(UIMenu(
                    title: "",
                    options: .displayInline,
                    children: [
                        self.renameAction(indexPath: indexPath),
                        self.deleteAction(indexPath: indexPath),
                    ]
                ))

                return UIMenu(title: "", children: menuElements)
            }
        )
    }

    func makePseudoFeedContextMenu(indexPath: IndexPath) -> UIContextMenuConfiguration? {
        guard let markAllAction = self.markAllAsReadAction(indexPath: indexPath) else {
            return nil
        }

        return UIContextMenuConfiguration(
            identifier: MainFeedRowIdentifier(indexPath: indexPath),
            previewProvider: nil,
            actionProvider: { _ in
                UIMenu(title: "", children: [markAllAction])
            }
        )
    }
}

// MARK: - Action Builders

extension MainFeedCollectionViewController {
    func moveToFolderAction(indexPath: IndexPath) -> UIAction? {
        guard self.coordinator.nodeFor(indexPath)?.representedObject is Feed else {
            return nil
        }

        let title = NSLocalizedString("Move to Folder...", comment: "Move to Folder")
        let action = UIAction(title: title, image: UIImage(systemName: "folder")) { [weak self] _ in
            self?.showFolderPickerForMoving(indexPath: indexPath)
        }
        return action
    }

    func showFolderPickerForMoving(indexPath: IndexPath) {
        guard
            let node = coordinator.nodeFor(indexPath),
            let feed = node.representedObject as? Feed,
            let sourceContainer = node.parent?.representedObject as? Container else { return }

        self.feedBeingMoved = (feed: feed, sourceContainer: sourceContainer)

        let folderViewController = AddFeedFolderViewController()
        folderViewController.delegate = self
        folderViewController.initialContainer = sourceContainer

        let navController = UINavigationController(rootViewController: folderViewController)
        navController.modalPresentationStyle = .formSheet
        present(navController, animated: true)
    }

    func markAllAsReadAlertAction(indexPath: IndexPath, completion: @escaping (Bool) -> Void) -> UIAlertAction? {
        guard
            let feed = coordinator.nodeFor(indexPath)?.representedObject as? Feed,
            feed.unreadCount > 0,
            let articles = try? feed.fetchArticles() else
        {
            return nil
        }

        let title = NSLocalizedString("Mark All as Read", comment: "Mark All as Read")
        let action = UIAlertAction(title: title, style: .default) { [weak self] _ in
            self?.coordinator.markAllAsRead(Array(articles))
            completion(true)
        }
        return action
    }

    func deleteAction(indexPath: IndexPath) -> UIAction {
        let title = NSLocalizedString("Delete", comment: "Delete")

        let action = UIAction(title: title, image: Assets.Images.trash, attributes: .destructive) { [weak self] _ in
            self?.delete(indexPath: indexPath)
        }
        return action
    }

    func renameAction(indexPath: IndexPath) -> UIAction {
        let title = NSLocalizedString("Rename", comment: "Rename")
        let action = UIAction(title: title, image: Assets.Images.edit) { [weak self] _ in
            self?.rename(indexPath: indexPath)
        }
        return action
    }

    func getInfoAction(indexPath: IndexPath) -> UIAction? {
        guard
            let node = coordinator.nodeFor(indexPath),
            let feed = node.representedObject as? Feed else
        {
            return nil
        }
        let container = node.parent?.representedObject as? Container

        let title = NSLocalizedString("Info", comment: "Info")
        let action = UIAction(title: title, image: Assets.Images.info) { [weak self] _ in
            self?.coordinator.showFeedInspector(for: feed, in: container)
        }
        return action
    }

    func getInfoAlertAction(indexPath: IndexPath, completion: @escaping (Bool) -> Void) -> UIAlertAction? {
        guard
            let node = coordinator.nodeFor(indexPath),
            let feed = node.representedObject as? Feed else
        {
            return nil
        }
        let container = node.parent?.representedObject as? Container

        let title = NSLocalizedString("Info", comment: "Info")
        let action = UIAlertAction(title: title, style: .default) { [weak self] _ in
            self?.coordinator.showFeedInspector(for: feed, in: container)
            completion(true)
        }
        return action
    }

    func markAllAsReadAction(indexPath: IndexPath) -> UIAction? {
        guard
            let sidebarItem = coordinator.nodeFor(indexPath)?.representedObject as? SidebarItem,
            sidebarItem.unreadCount > 0 else
        {
            return nil
        }

        let title = NSLocalizedString("Mark All as Read", comment: "Mark All as Read")
        let action = UIAction(title: title, image: Assets.Images.markAllAsRead) { [weak self] _ in
            if let articles = try? sidebarItem.fetchUnreadArticles() {
                self?.coordinator.markAllAsRead(Array(articles))
            }
        }

        return action
    }

    func markAllAsReadAction(dataStore: DataStore, contentView _: UIView?) -> UIAction? {
        guard dataStore.unreadCount > 0 else {
            return nil
        }

        let title = NSLocalizedString("Mark All as Read", comment: "Mark All as Read")
        let action = UIAction(title: title, image: Assets.Images.markAllAsRead) { [weak self] _ in
            if let articles = try? dataStore.fetchArticles(.unread()) {
                self?.coordinator.markAllAsRead(Array(articles))
            }
        }

        return action
    }

    func rename(indexPath: IndexPath) {
        guard let sidebarItem = coordinator.nodeFor(indexPath)?.representedObject as? SidebarItem else { return }

        let formatString = NSLocalizedString("Rename \u{201C}%@\u{201D}", comment: "Rename feed")
        let title = NSString.localizedStringWithFormat(formatString as NSString, sidebarItem.nameForDisplay) as String

        let alertController = UIAlertController(title: title, message: nil, preferredStyle: .alert)

        let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel")
        alertController.addAction(UIAlertAction(title: cancelTitle, style: .cancel))

        let renameTitle = NSLocalizedString("Rename", comment: "Rename")
        let renameAction = UIAlertAction(title: renameTitle, style: .default) { [weak self] _ in
            guard let name = alertController.textFields?[0].text, !name.isEmpty else {
                return
            }

            if let feed = sidebarItem as? Feed {
                feed.rename(to: name) { result in
                    switch result {
                    case .success:
                        break
                    case let .failure(error):
                        self?.presentError(error)
                    }
                }
            } else if let folder = sidebarItem as? Folder {
                folder.rename(to: name) { result in
                    switch result {
                    case .success:
                        break
                    case let .failure(error):
                        self?.presentError(error)
                    }
                }
            }
        }

        alertController.addAction(renameAction)
        alertController.preferredAction = renameAction

        alertController.addTextField { textField in
            textField.text = sidebarItem.nameForDisplay
            textField.placeholder = NSLocalizedString("Name", comment: "Name")
            textField.clearButtonMode = .always
        }

        self.present(alertController, animated: true) {}
    }

    func delete(indexPath: IndexPath) {
        guard let sidebarItem = coordinator.nodeFor(indexPath)?.representedObject as? SidebarItem else { return }

        let title: String
        let message: String
        if sidebarItem is Folder {
            title = NSLocalizedString("Delete Folder", comment: "Delete folder")
            let localizedInformativeText = NSLocalizedString(
                "Are you sure you want to delete the \u{201C}%@\u{201D} folder?",
                comment: "Folder delete text"
            )
            message = NSString.localizedStringWithFormat(
                localizedInformativeText as NSString,
                sidebarItem.nameForDisplay
            ) as String
        } else {
            title = NSLocalizedString("Delete Feed", comment: "Delete feed")
            let localizedInformativeText = NSLocalizedString(
                "Are you sure you want to delete the \u{201C}%@\u{201D} feed?",
                comment: "Feed delete text"
            )
            message = NSString.localizedStringWithFormat(
                localizedInformativeText as NSString,
                sidebarItem.nameForDisplay
            ) as String
        }

        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)

        let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel")
        alertController.addAction(UIAlertAction(title: cancelTitle, style: .cancel))

        let deleteTitle = NSLocalizedString("Delete", comment: "Delete")
        let deleteAction = UIAlertAction(title: deleteTitle, style: .destructive) { [weak self] _ in
            self?.performDelete(indexPath: indexPath)
        }
        alertController.addAction(deleteAction)
        alertController.preferredAction = deleteAction

        self.present(alertController, animated: true)
    }

    func performDelete(indexPath: IndexPath) {
        guard
            let undoManager,
            let deleteNode = coordinator.nodeFor(indexPath),
            let deleteCommand = DeleteCommand(
                nodesToDelete: [deleteNode],
                undoManager: undoManager,
                errorHandler: self.errorPresenter()
            ) else
        {
            return
        }

        if indexPath == self.coordinator.currentFeedIndexPath {
            self.coordinator.selectFeed(indexPath: nil)
        }

        pushUndoableCommand(deleteCommand)
        deleteCommand.perform()
    }
}

// MARK: - AddFeedFolderViewControllerDelegate

extension MainFeedCollectionViewController: AddFeedFolderViewControllerDelegate {
    func didSelect(container: Container) {
        guard let (feed, sourceContainer) = feedBeingMoved else { return }

        self.feedBeingMoved = nil

        if sourceContainer.dataStore == container.dataStore {
            moveFeedInAccount(feed: feed, sourceContainer: sourceContainer, destinationContainer: container)
        } else {
            moveFeedBetweenAccounts(feed: feed, sourceContainer: sourceContainer, destinationContainer: container)
        }
    }
}

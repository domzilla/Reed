//
//  MainFeedCollectionViewController.swift
//  Reed
//
//  Created by Stuart Breckenridge on 23/06/2025.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import SafariServices
import UIKit
import UniformTypeIdentifiers
import WebKit

private let reuseIdentifier = "FeedCell"
private let folderIdentifier = "Folder"

final class MainFeedRowIdentifier: NSObject, NSCopying {
    var indexPath: IndexPath

    init(indexPath: IndexPath) {
        self.indexPath = indexPath
    }

    func copy(with _: NSZone? = nil) -> Any {
        self
    }
}

private let containerReuseIdentifier = "Container"

final class MainFeedCollectionViewController: UICollectionViewController, UndoableCommandRunner {
    // MARK: - UI Elements

    private lazy var filterButton: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: Assets.Images.filter,
            style: .plain,
            target: self,
            action: #selector(self.toggleFilter(_:))
        )
        item.accessibilityLabel = NSLocalizedString("Filter Read Feeds", comment: "Filter Read Feeds")
        return item
    }()

    private lazy var addNewItemButton: UIBarButtonItem = {
        let item = UIBarButtonItem(image: UIImage(systemName: "plus"), style: .plain, target: nil, action: nil)
        item.accessibilityLabel = NSLocalizedString("Add", comment: "Add")
        return item
    }()

    private lazy var settingsButton: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: UIImage(systemName: "gear"),
            style: .plain,
            target: self,
            action: #selector(settings(_:))
        )
        item.accessibilityLabel = NSLocalizedString("Settings", comment: "Settings")
        return item
    }()

    private let keyboardManager = KeyboardManager(type: .sidebar)
    override var keyCommands: [UIKeyCommand]? {
        // If the first responder is the WKWebView (PreloadedWebView) we don't want to supply any keyboard
        // commands that the system is looking for by going up the responder chain. They will interfere with
        // the WKWebViews built in hardware keyboard shortcuts, specifically the up and down arrow keys.
        guard let current = UIResponder.currentFirstResponder, !(current is PreloadedWebView) else { return nil }

        return self.keyboardManager.keyCommands
    }

    override var canBecomeFirstResponder: Bool {
        true
    }

    var undoableCommands = [UndoableCommand]()
    weak var coordinator: SceneCoordinator!

    /// On iPhone, this property is used to prevent the user from selecting a new feed while the current feed is being
    /// deselected.
    /// While `isAnimating` is `true`, `shouldSelectItemAt()` will not allow new selection.
    /// The value is set to `true` in `viewWillAppear(_:)` if a feed is selected, and reset to `false` in
    /// `viewDidAppear(_:)` after a delay to allow the deselection animation to complete.
    private var isAnimating: Bool = false

    /// Tracks the index path of the feed being moved via the "Move to..." context menu action
    var feedIndexPathBeingMoved: IndexPath?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set up navigation bar (filter on right, matching storyboard)
        navigationItem.rightBarButtonItem = self.filterButton

        // Set up toolbar (settings left, add right, matching storyboard)
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        toolbarItems = [self.settingsButton, flexSpace, self.addNewItemButton]

        self.registerForNotifications()
        self.configureCollectionView()
        self.collectionView.dragDelegate = self
        self.collectionView.dropDelegate = self
        becomeFirstResponder()
    }

    override func viewWillAppear(_ animated: Bool) {
        navigationController?.isToolbarHidden = false
        self.updateUI()
        super.viewWillAppear(animated)

        self.collectionView.refreshControl = UIRefreshControl()
        self.collectionView.refreshControl!.addTarget(
            self,
            action: #selector(self.refreshAccounts(_:)),
            for: .valueChanged
        )

        if traitCollection.userInterfaceIdiom == .phone {
            self.navigationController?.navigationBar.prefersLargeTitles = false

            /// On iPhone, we want to deselect the feed when the user navigates
            /// back to the feeds view. To prevent the user from selecting a new feed while
            /// the current feed is being deselected, set `isAnimating` to true.
            ///
            /// `shouldSelectItemAt()` will not allow selection when `isAnimating`
            /// is `true.`
            if let _ = collectionView.indexPathsForSelectedItems {
                self.isAnimating = true
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        /// On iPhone, once the deselection animation has completed, set `isAnimating`
        /// to false and this will allow selection.
        if traitCollection.userInterfaceIdiom == .phone {
            if let _ = collectionView.indexPathsForSelectedItems {
                self.coordinator.selectFeed(indexPath: nil, animations: [.select])
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.isAnimating = false
                }
            }
        }
    }

    func registerForNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.unreadCountDidChange(_:)),
            name: .UnreadCountDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.faviconDidBecomeAvailable(_:)),
            name: .FaviconDidBecomeAvailable,
            object: nil
        )
        // TODO: fix this temporary hack, which will probably require refactoring image handling.
        // We want to know when to possibly reconfigure our cells with a new image, and we don't
        // always know when an image is available — but watching the .htmlMetadataAvailable Notification
        // lets us know that it's time to request an image.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.faviconDidBecomeAvailable(_:)),
            name: .htmlMetadataAvailable,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.feedIconDidBecomeAvailable(_:)),
            name: .feedIconDidBecomeAvailable,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.feedSettingDidChange(_:)),
            name: .feedSettingDidChange,
            object: nil
        )

        registerForTraitChanges(
            [UITraitPreferredContentSizeCategory.self],
            target: self,
            action: #selector(self.preferredContentSizeCategoryDidChange)
        )
    }

    // MARK: - Collection View Configuration

    func configureCollectionView() {
        var config = UICollectionLayoutListConfiguration(appearance: traitCollection
            .userInterfaceIdiom == .pad ? .sidebar : .insetGrouped)
        config.separatorConfiguration.color = .tertiarySystemFill
        config.headerMode = .supplementary

        config.trailingSwipeActionsConfigurationProvider = { [unowned self] indexPath in
            if indexPath.section == 0 { return UISwipeActionsConfiguration(actions: []) }
            var actions = [UIContextualAction]()

            // Set up the delete action
            let deleteTitle = NSLocalizedString("Delete", comment: "Delete")
            let deleteAction = UIContextualAction(style: .destructive, title: nil) { [weak self] _, _, completion in
                self?.delete(indexPath: indexPath)
                completion(true)
            }
            deleteAction.image = UIImage(systemName: "trash")
            deleteAction.accessibilityLabel = deleteTitle
            deleteAction.backgroundColor = UIColor.systemRed
            actions.append(deleteAction)

            // Set up the rename action
            let renameTitle = NSLocalizedString("Rename", comment: "Rename")
            let renameAction = UIContextualAction(style: .normal, title: nil) { [weak self] _, _, completion in
                self?.rename(indexPath: indexPath)
                completion(true)
            }
            renameAction.backgroundColor = UIColor.systemOrange
            renameAction.image = UIImage(systemName: "pencil")
            renameAction.accessibilityLabel = renameTitle
            actions.append(renameAction)

            if let feed = coordinator.nodeFor(indexPath)?.representedObject as? Feed {
                let moreTitle = NSLocalizedString("More", comment: "More")
                let moreAction = UIContextualAction(style: .normal, title: nil) { [weak self] _, view, completion in
                    if let self {
                        let alert = UIAlertController(
                            title: feed.nameForDisplay,
                            message: nil,
                            preferredStyle: .actionSheet
                        )
                        if let popoverController = alert.popoverPresentationController {
                            popoverController.sourceView = view
                            popoverController.sourceRect = CGRect(
                                x: view.frame.size.width / 2,
                                y: view.frame.size.height / 2,
                                width: 1,
                                height: 1
                            )
                        }

                        if let action = self.getInfoAlertAction(indexPath: indexPath, completion: completion) {
                            alert.addAction(action)
                        }

                        if let action = self.homePageAlertAction(indexPath: indexPath, completion: completion) {
                            alert.addAction(action)
                        }

                        if let action = self.copyFeedPageAlertAction(indexPath: indexPath, completion: completion) {
                            alert.addAction(action)
                        }

                        if let action = self.copyHomePageAlertAction(indexPath: indexPath, completion: completion) {
                            alert.addAction(action)
                        }

                        if let action = self.markAllAsReadAlertAction(indexPath: indexPath, completion: completion) {
                            alert.addAction(action)
                        }

                        let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel")
                        alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel) { _ in
                            completion(true)
                        })

                        self.present(alert, animated: true)
                    }
                }

                moreAction.backgroundColor = UIColor.systemGray
                moreAction.image = UIImage(systemName: "ellipsis")
                moreAction.accessibilityLabel = moreTitle
                actions.append(moreAction)
            }

            let config = UISwipeActionsConfiguration(actions: actions)
            config.performsFirstActionWithFullSwipe = false

            return config
        }

        let layout = UICollectionViewCompositionalLayout.list(using: config)
        self.collectionView.setCollectionViewLayout(layout, animated: false)
        self.collectionView.refreshControl = UIRefreshControl()
        self.collectionView.refreshControl!.addTarget(
            self,
            action: #selector(self.refreshAccounts(_:)),
            for: .valueChanged
        )

        // Register cells and supplementary views
        self.collectionView.register(MainFeedCollectionViewCell.self, forCellWithReuseIdentifier: reuseIdentifier)
        self.collectionView.register(
            MainFeedCollectionViewFolderCell.self,
            forCellWithReuseIdentifier: folderIdentifier
        )
        self.collectionView.register(
            MainFeedCollectionHeaderReusableView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: containerReuseIdentifier
        )

        if config.appearance == .sidebar {
            // This defrosts the glass.
            self.collectionView.backgroundColor = .clear
        }
    }

    @objc
    func settings(_: UIBarButtonItem) {
        self.coordinator.showSettings()
    }

    // MARK: UICollectionViewDataSource

    override func numberOfSections(in _: UICollectionView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        self.coordinator.numberOfSections()
    }

    override func collectionView(_: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of items
        self.coordinator.numberOfRows(in: section)
    }

    override func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    )
        -> UICollectionViewCell
    {
        guard let node = coordinator.nodeFor(indexPath), let _ = node.representedObject as? Folder else {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: reuseIdentifier,
                for: indexPath
            ) as? MainFeedCollectionViewCell
            self.configure(cell!, indexPath: indexPath)
            return cell!
        }

        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: folderIdentifier,
            for: indexPath
        ) as! MainFeedCollectionViewFolderCell
        self.configure(cell, indexPath: indexPath)
        cell.delegate = self
        return cell
    }

    override func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    )
        -> UICollectionReusableView
    {
        guard kind == UICollectionView.elementKindSectionHeader else {
            return UICollectionReusableView()
        }

        let headerView = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: containerReuseIdentifier,
            for: indexPath
        ) as! MainFeedCollectionHeaderReusableView

        guard
            let nameProvider = coordinator.rootNode.childAtIndex(indexPath.section)?
                .representedObject as? DisplayNameProvider else
        {
            return UICollectionReusableView()
        }

        headerView.delegate = self
        headerView.headerTitle.text = nameProvider.nameForDisplay

        guard let sectionNode = coordinator.rootNode.childAtIndex(indexPath.section) else {
            return headerView
        }

        if let dataStore = sectionNode.representedObject as? DataStore {
            headerView.unreadCount = dataStore.unreadCount
        } else {
            headerView.unreadCount = 0
        }

        headerView.tag = indexPath.section
        headerView.disclosureExpanded = self.coordinator.isExpanded(sectionNode)

        if indexPath.section != 0 {
            headerView.addInteraction(UIContextMenuInteraction(delegate: self))
        }

        return headerView
    }

    override func collectionView(_: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        becomeFirstResponder()
        self.coordinator.selectFeed(indexPath: indexPath, animations: [.navigation, .select, .scroll])
    }

    // MARK: UICollectionViewDelegate

    /*
     // Uncomment this method to specify if the specified item should be highlighted during tracking
     override func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
         return true
     }
     */

    // Uncomment this method to specify if the specified item should be selected
    override func collectionView(_: UICollectionView, shouldSelectItemAt _: IndexPath) -> Bool {
        if traitCollection.userInterfaceIdiom == .pad { return true }
        return !self.isAnimating
    }

    override func collectionView(_: UICollectionView, shouldShowMenuForItemAt _: IndexPath) -> Bool {
        true
    }

    override func collectionView(
        _: UICollectionView,
        canPerformAction _: Selector,
        forItemAt _: IndexPath,
        withSender _: Any?
    )
        -> Bool
    {
        false
    }

    override func collectionView(
        _: UICollectionView,
        performAction _: Selector,
        forItemAt _: IndexPath,
        withSender _: Any?
    ) {}

    override func collectionView(
        _: UICollectionView,
        contextMenuConfigurationForItemAt indexPath: IndexPath,
        point _: CGPoint
    )
        -> UIContextMenuConfiguration?
    {
        guard let sidebarItem = coordinator.nodeFor(indexPath)?.representedObject as? SidebarItem else {
            return nil
        }
        if sidebarItem is Feed {
            return makeFeedContextMenu(indexPath: indexPath, includeDeleteRename: true)
        } else if sidebarItem is Folder {
            return makeFolderContextMenu(indexPath: indexPath)
        } else if sidebarItem is PseudoFeed {
            return makePseudoFeedContextMenu(indexPath: indexPath)
        } else {
            return nil
        }
    }

    // MARK: - API

    func focus() {
        becomeFirstResponder()
    }

    func updateUI() {
        if self.coordinator.isReadFeedsFiltered {
            self.setFilterButtonToActive()
        } else {
            self.setFilterButtonToInactive()
        }
        self.addNewItemButton.isEnabled = !DataStore.shared.activeDataStores.isEmpty

        self.configureContextMenu()
    }

    func updateFeedSelection(animations: Animations) {
        if let indexPath = coordinator.currentFeedIndexPath {
            self.selectCollectionViewItemIfNotVisible(at: indexPath, animations: animations)
        } else {
            if let indexPath = collectionView.indexPathsForSelectedItems?.first {
                if animations.contains(.select) {
                    self.collectionView.deselectItem(at: indexPath, animated: true)
                } else {
                    self.collectionView.deselectItem(at: indexPath, animated: false)
                }
            }
        }
    }

    func openInAppBrowser() {
        if
            let indexPath = coordinator.currentFeedIndexPath,
            let url = coordinator.homePageURLForFeed(indexPath)
        {
            let vc = SFSafariViewController(url: url)
            vc.modalPresentationStyle = .overFullScreen
            present(vc, animated: true)
        }
    }

    func reloadFeeds(initialLoad: Bool, changes: ShadowTableChanges, completion: (() -> Void)? = nil) {
        self.updateUI()

        guard !initialLoad else {
            self.collectionView.reloadData()
            completion?()
            return
        }

        self.collectionView.performBatchUpdates {
            if let deletes = changes.deletes, !deletes.isEmpty {
                self.collectionView.deleteSections(IndexSet(deletes))
            }

            if let inserts = changes.inserts, !inserts.isEmpty {
                self.collectionView.insertSections(IndexSet(inserts))
            }

            if let moves = changes.moves, !moves.isEmpty {
                for move in moves {
                    self.collectionView.moveSection(move.from, toSection: move.to)
                }
            }

            if let rowChanges = changes.rowChanges {
                for rowChange in rowChanges {
                    if let deletes = rowChange.deleteIndexPaths, !deletes.isEmpty {
                        self.collectionView.deleteItems(at: deletes)
                    }

                    if let inserts = rowChange.insertIndexPaths, !inserts.isEmpty {
                        self.collectionView.insertItems(at: inserts)
                    }

                    if let moves = rowChange.moveIndexPaths, !moves.isEmpty {
                        for move in moves {
                            self.collectionView.moveItem(at: move.0, to: move.1)
                        }
                    }
                }
            }
        }

        if let rowChanges = changes.rowChanges {
            for rowChange in rowChanges {
                if let reloads = rowChange.reloadIndexPaths, !reloads.isEmpty {
                    self.collectionView.reloadItems(at: reloads)
                }
            }
        }

        completion?()
    }

    func applyToAvailableCells(_ completion: (MainFeedCollectionViewCell, IndexPath) -> Void) {
        for cell in self.collectionView.visibleCells {
            guard let indexPath = collectionView.indexPath(for: cell) else { continue }
            if let cell = collectionView.cellForItem(at: indexPath) as? MainFeedCollectionViewCell {
                completion(cell, indexPath)
            }
        }
    }

    func configureIcon(_ cell: MainFeedCollectionViewCell, _ indexPath: IndexPath) {
        guard
            let node = coordinator.nodeFor(indexPath), let sidebarItem = node.representedObject as? SidebarItem,
            let sidebarItemID = sidebarItem.sidebarItemID else
        {
            return
        }
        cell.iconImage = IconImageCache.shared.imageFor(sidebarItemID)
    }

    func configureIcon(_ cell: MainFeedCollectionViewFolderCell, _ indexPath: IndexPath) {
        guard
            let node = coordinator.nodeFor(indexPath), let sidebarItem = node.representedObject as? SidebarItem,
            let sidebarItemID = sidebarItem.sidebarItemID else
        {
            return
        }
        cell.iconImage = IconImageCache.shared.imageFor(sidebarItemID)
    }

    func configureCellsForRepresentedObject(_: AnyObject) {
        // applyToCellsForRepresentedObject(representedObject, configure)
    }

    func applyToCellsForRepresentedObject(
        _ representedObject: AnyObject,
        _ completion: (MainFeedCollectionViewCell, IndexPath) -> Void
    ) {
        self.applyToAvailableCells { cell, indexPath in
            if
                let node = coordinator.nodeFor(indexPath),
                let representedSidebarItem = representedObject as? SidebarItem,
                let candidateSidebarItem = node.representedObject as? SidebarItem,
                representedSidebarItem.sidebarItemID == candidateSidebarItem.sidebarItemID
            {
                completion(cell, indexPath)
            }
        }
    }

    func restoreSelectionIfNecessary(adjustScroll: Bool) {
        if let indexPath = coordinator.mainFeedIndexPathForCurrentTimeline() {
            if adjustScroll {
                self.selectCollectionViewItemIfNotVisible(at: indexPath, animations: [])
            } else {
                self.collectionView.selectItem(at: indexPath, animated: false, scrollPosition: .centeredVertically)
            }
        }
    }

    // MARK: - Private

    private func selectCollectionViewItemIfNotVisible(at indexPath: IndexPath, animations: Animations) {
        guard
            let dataSource = collectionView.dataSource,
            let numberOfSections = dataSource.numberOfSections,
            indexPath.section < numberOfSections(collectionView),
            indexPath.row < dataSource.collectionView(collectionView, numberOfItemsInSection: indexPath.section) else
        {
            return
        }

        self.collectionView.selectItem(at: indexPath, animated: animations.contains(.select), scrollPosition: [])

        if !self.collectionView.indexPathsForVisibleItems.contains(indexPath) {
            self.collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: true)
        }
    }

    /// Configure standard feed cells
    func configure(_ cell: MainFeedCollectionViewCell, indexPath: IndexPath) {
        guard let node = coordinator.nodeFor(indexPath) else { return }
        var indentationLevel = 0
        if let _ = node.parent?.representedObject as? Folder {
            indentationLevel = 1
        }

        if let sidebarItem = node.representedObject as? SidebarItem {
            cell.feedTitle.text = sidebarItem.nameForDisplay
            cell.unreadCount = sidebarItem.unreadCount
            cell.indentationLevel = indentationLevel
            self.configureIcon(cell, indexPath)
        }
    }

    /// Configure folders
    func configure(_ cell: MainFeedCollectionViewFolderCell, indexPath: IndexPath) {
        guard let node = coordinator.nodeFor(indexPath) else { return }

        if let folder = node.representedObject as? Folder {
            cell.folderTitle.text = folder.nameForDisplay
            cell.unreadCount = folder.unreadCount
            self.configureIcon(cell, indexPath)
        }

        if let containerID = (node.representedObject as? Container)?.containerID {
            cell.setDisclosure(isExpanded: self.coordinator.isExpanded(containerID), animated: false)
        }
    }

    private func headerViewForDataStore(_ dataStore: DataStore) -> MainFeedCollectionHeaderReusableView? {
        guard
            let node = coordinator.rootNode.childNodeRepresentingObject(dataStore),
            let sectionIndex = coordinator.rootNode.indexOfChild(node) else
        {
            return nil
        }
        if sectionIndex == 0 { return nil }

        return self.collectionView.supplementaryView(
            forElementKind: UICollectionView.elementKindSectionHeader,
            at: IndexPath(item: 0, section: sectionIndex)
        ) as? MainFeedCollectionHeaderReusableView
    }

    private func reloadAllVisibleCells(completion _: (() -> Void)? = nil) {
        guard let indexPaths = collectionView.indexPathsForSelectedItems else { return }
        self.collectionView.reloadItems(at: indexPaths)
        self.restoreSelectionIfNecessary(adjustScroll: false)
    }

    func setFilterButtonToActive() {
        self.filterButton.tintColor = Assets.Colors.primaryAccent
        self.filterButton.accLabelText = NSLocalizedString(
            "Selected - Filter Read Feeds",
            comment: "Selected - Filter Read Feeds"
        )
    }

    func setFilterButtonToInactive() {
        self.filterButton.tintColor = .label
        self.filterButton.accLabelText = NSLocalizedString("Filter Read Feeds", comment: "Filter Read Feeds")
    }

    // MARK: - Notifications

    @objc
    func preferredContentSizeCategoryDidChange() {
        IconImageCache.shared.emptyCache()
        self.reloadAllVisibleCells()
    }

    @objc
    func unreadCountDidChange(_ note: Notification) {
        self.updateUI()

        guard let unreadCountProvider = note.object as? UnreadCountProvider else {
            return
        }

        if let dataStore = unreadCountProvider as? DataStore {
            if let headerView = headerViewForDataStore(dataStore) {
                headerView.unreadCount = dataStore.unreadCount
            }
            return
        }

        let node: Node? = self.coordinator.rootNode.descendantNodeRepresentingObject(unreadCountProvider as AnyObject)

        guard let unreadCountNode = node, let indexPath = coordinator.indexPathFor(unreadCountNode) else { return }

        if let cell = collectionView.cellForItem(at: indexPath) as? MainFeedCollectionViewCell {
            cell.unreadCount = unreadCountProvider.unreadCount
        }

        if let cell = collectionView.cellForItem(at: indexPath) as? MainFeedCollectionViewFolderCell {
            cell.unreadCount = unreadCountProvider.unreadCount
        }
    }

    @objc
    func feedSettingDidChange(_ note: Notification) {
        guard let feed = note.object as? Feed, let key = note.userInfo?[Feed.SettingUserInfoKey] as? String else {
            return
        }
        if key == Feed.SettingKey.homePageURL || key == Feed.SettingKey.faviconURL {
            self.configureCellsForRepresentedObject(feed)
        }
    }

    @objc
    func faviconDidBecomeAvailable(_: Notification) {
        self.applyToAvailableCells(self.configureIcon)
    }

    @objc
    func feedIconDidBecomeAvailable(_ note: Notification) {
        guard let feed = note.userInfo?[UserInfoKey.feed] as? Feed else {
            return
        }
        self.applyToCellsForRepresentedObject(feed, self.configureIcon(_:_:))
    }

    // MARK: - Actions

    @objc
    func configureContextMenu(_: Any? = nil) {
        /*
         	Context Menu Order (matching storyboard):
         	1. Add Feed
         	2. Add Folder
         */

        var menuItems: [UIAction] = []

        let addFeedActionTitle = NSLocalizedString("Add Feed", comment: "Add Feed")
        let addFeedAction = UIAction(title: addFeedActionTitle, image: Assets.Images.plus) { _ in
            self.coordinator.showAddFeed()
        }
        menuItems.append(addFeedAction)

        let addFolderActionTitle = NSLocalizedString("Add Folder", comment: "Add Folder")
        let addFolderAction = UIAction(title: addFolderActionTitle, image: Assets.Images.folderOutlinePlus) { _ in
            self.coordinator.showAddFolder()
        }

        menuItems.append(addFolderAction)

        // Reverse to show Add Feed first (menus render bottom-to-top)
        let contextMenu = UIMenu(
            title: NSLocalizedString("Add Item", comment: "Add Item"),
            image: nil,
            identifier: nil,
            options: [],
            children: menuItems.reversed()
        )

        self.addNewItemButton.menu = contextMenu
    }

    @objc
    func refreshAccounts(_: Any) {
        self.collectionView.refreshControl?.endRefreshing()

        // This is a hack to make sure that an error dialog doesn't interfere with dismissing the refreshControl.
        // If the error dialog appears too closely to the call to endRefreshing, then the refreshControl never
        // disappears.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            appDelegate.manualRefresh(errorHandler: self.errorPresenter())
        }
    }

    @objc
    func add(_ sender: UIBarButtonItem) {
        let title = NSLocalizedString("Add Item", comment: "Add Item")
        let alertController = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)

        let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel")
        let cancelAction = UIAlertAction(title: cancelTitle, style: .cancel)

        let addFeedActionTitle = NSLocalizedString("Add Web Feed", comment: "Add Web Feed")
        let addFeedAction = UIAlertAction(title: addFeedActionTitle, style: .default) { _ in
            self.coordinator.showAddFeed()
        }

        let addFolderActionTitle = NSLocalizedString("Add Folder", comment: "Add Folder")
        let addFolderAction = UIAlertAction(title: addFolderActionTitle, style: .default) { _ in
            self.coordinator.showAddFolder()
        }

        alertController.addAction(addFeedAction)

        alertController.addAction(addFolderAction)
        alertController.addAction(cancelAction)

        alertController.popoverPresentationController?.barButtonItem = sender

        present(alertController, animated: true)
    }

    @objc
    func toggleFilter(_: Any) {
        self.coordinator.toggleReadFeedsFilter()
    }

    func toggle(_ headerView: MainFeedCollectionHeaderReusableView) {
        guard let sectionNode = coordinator.rootNode.childAtIndex(headerView.tag) else {
            return
        }

        if self.coordinator.isExpanded(sectionNode) {
            headerView.disclosureExpanded = false
            self.coordinator.collapse(sectionNode)
        } else {
            headerView.disclosureExpanded = true
            self.coordinator.expand(sectionNode)
        }
    }
}

// MARK: - MainFeedCollectionHeaderReusableViewDelegate

extension MainFeedCollectionViewController: MainFeedCollectionHeaderReusableViewDelegate {
    func mainFeedCollectionHeaderReusableViewDidTapDisclosureIndicator(_ view: MainFeedCollectionHeaderReusableView) {
        self.toggle(view)
    }
}

// MARK: - MainFeedCollectionViewFolderCellDelegate

extension MainFeedCollectionViewController: MainFeedCollectionViewFolderCellDelegate {
    func mainFeedCollectionFolderViewCellDisclosureDidToggle(
        _ sender: MainFeedCollectionViewFolderCell,
        expanding: Bool
    ) {
        if expanding {
            self.expand(sender)
        } else {
            self.collapse(sender)
        }
    }

    func expand(_ cell: MainFeedCollectionViewFolderCell) {
        guard let indexPath = collectionView.indexPath(for: cell), let node = coordinator.nodeFor(indexPath) else {
            return
        }
        self.coordinator.expand(node)
    }

    func collapse(_ cell: MainFeedCollectionViewFolderCell) {
        guard let indexPath = collectionView.indexPath(for: cell), let node = coordinator.nodeFor(indexPath) else {
            return
        }
        self.coordinator.collapse(node)
    }
}

// MARK: - UIContextMenuInteractionDelegate

extension MainFeedCollectionViewController: UIContextMenuInteractionDelegate {
    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        configurationForMenuAtLocation _: CGPoint
    )
        -> UIContextMenuConfiguration?
    {
        guard
            let sectionIndex = interaction.view?.tag,
            let sectionNode = coordinator.rootNode.childAtIndex(sectionIndex),
            let dataStore = sectionNode.representedObject as? DataStore else
        {
            return nil
        }

        return UIContextMenuConfiguration(identifier: sectionIndex as NSCopying, previewProvider: nil) { _ in
            var menuElements = [UIMenuElement]()

            // Just show Mark All as Read - no account management needed
            if let markAllAction = self.markAllAsReadAction(dataStore: dataStore, contentView: interaction.view) {
                menuElements.append(UIMenu(title: "", options: .displayInline, children: [markAllAction]))
            }

            return UIMenu(title: "", children: menuElements)
        }
    }

    func contextMenuInteraction(
        _: UIContextMenuInteraction,
        previewForHighlightingMenuWithConfiguration configuration: UIContextMenuConfiguration
    )
        -> UITargetedPreview?
    {
        guard
            let sectionIndex = configuration.identifier as? Int,
            let cell = collectionView.supplementaryView(
                forElementKind: UICollectionView.elementKindSectionHeader,
                at: IndexPath(item: 0, section: sectionIndex)
            ) as? MainFeedCollectionHeaderReusableView else
        {
            return nil
        }

        let params = UIPreviewParameters()
        let insetBounds = CGRect(x: 1, y: 1, width: cell.bounds.width - 2, height: cell.bounds.height - 2)
        params.visiblePath = UIBezierPath(roundedRect: insetBounds, cornerRadius: 10)
        return UITargetedPreview(view: cell, parameters: params)
    }
}

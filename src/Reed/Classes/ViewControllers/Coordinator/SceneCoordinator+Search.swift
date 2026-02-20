//
//  SceneCoordinator+Search.swift
//  Reed
//

import UIKit

extension SceneCoordinator {
    func showSearch(scope: SearchScope = .global, articleIDs: Set<String>? = nil) {
        let searchVC = SearchViewController(scope: scope, articleIDs: articleIDs)
        searchVC.coordinator = self
        let nav = UINavigationController(rootViewController: searchVC)
        nav.modalPresentationStyle = .formSheet
        nav.preferredContentSize = SearchViewController.preferredContentSizeForFormSheetDisplay
        self.rootSplitViewController.present(nav, animated: true)
    }

    func toggleReadFeedsFilter() {
        let newValue = !self.isReadFeedsFiltered
        self.treeControllerDelegate.isReadFiltered = newValue
        AppDefaults.shared.hideReadFeeds = newValue
        rebuildBackingStores()
        self.mainFeedCollectionViewController?.updateUI()
        self.refreshTimeline(resetScroll: false)
    }

    func toggleReadArticlesFilter() {
        self.toggleReadFeedsFilter()
    }
}

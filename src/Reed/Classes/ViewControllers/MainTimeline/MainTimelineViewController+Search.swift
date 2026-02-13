//
//  MainTimelineViewController+Search.swift
//  Reed
//
//  Created by Dominic Rodemer on 12/02/2026.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import UIKit

// MARK: - UISearchControllerDelegate

extension MainTimelineViewController: UISearchControllerDelegate {
    func willPresentSearchController(_ searchController: UISearchController) {
        self.coordinator?.beginSearching()
        searchController.searchBar.showsScopeBar = true
    }

    func willDismissSearchController(_ searchController: UISearchController) {
        self.coordinator?.endSearching()
        searchController.searchBar.showsScopeBar = false
    }
}

// MARK: - UISearchResultsUpdating

extension MainTimelineViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let searchScope = SearchScope(rawValue: searchController.searchBar.selectedScopeButtonIndex)!
        searchArticles(searchController.searchBar.text!, searchScope)
    }
}

// MARK: - UISearchBarDelegate

extension MainTimelineViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        let searchScope = SearchScope(rawValue: selectedScope)!
        searchArticles(searchBar.text!, searchScope)
    }
}

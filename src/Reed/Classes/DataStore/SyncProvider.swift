//
//  SyncProvider.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/16/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSWeb

@MainActor protocol SyncProvider {

	var isOPMLImportInProgress: Bool { get }

	var server: String? { get }
	var dataStoreMetadata: DataStoreMetadata? { get set }

	var refreshProgress: DownloadProgress { get }

	func receiveRemoteNotification(for dataStore: DataStore, userInfo: [AnyHashable : Any]) async

	func refreshAll(for dataStore: DataStore) async throws
	func syncArticleStatus(for dataStore: DataStore) async throws
	func sendArticleStatus(for dataStore: DataStore) async throws
	func refreshArticleStatus(for dataStore: DataStore) async throws

	func importOPML(for dataStore: DataStore, opmlFile: URL) async throws

	func createFolder(for dataStore: DataStore, name: String) async throws -> Folder
	func renameFolder(for dataStore: DataStore, with folder: Folder, to name: String) async throws
	func removeFolder(for dataStore: DataStore, with folder: Folder) async throws

	func createFeed(for dataStore: DataStore, url: String, name: String?, container: Container, validateFeed: Bool) async throws -> Feed
	func renameFeed(for dataStore: DataStore, with feed: Feed, to name: String) async throws
	func addFeed(dataStore: DataStore, feed: Feed, container: Container) async throws
	func removeFeed(dataStore: DataStore, feed: Feed, container: Container) async throws
	func moveFeed(dataStore: DataStore, feed: Feed, sourceContainer: Container, destinationContainer: Container) async throws

	func restoreFeed(for dataStore: DataStore, feed: Feed, container: Container) async throws
	func restoreFolder(for dataStore: DataStore, folder: Folder) async throws

	func markArticles(for dataStore: DataStore, articles: Set<Article>, statusKey: ArticleStatus.Key, flag: Bool) async throws

	// Called at the end of dataStore's init method.
	func dataStoreDidInitialize(_ dataStore: DataStore)

	func dataStoreWillBeDeleted(_ dataStore: DataStore)

	/// Suspend all network activity
	func suspendNetwork()

	/// Suspend the SQLite databases
	func suspendDatabase()

	/// Make sure no SQLite databases are open and we are ready to issue network requests.
	func resume()
}

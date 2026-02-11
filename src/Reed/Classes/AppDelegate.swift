//
//  AppDelegate.swift
//  Reed
//
//  Created by Maurice Parker on 4/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import BackgroundTasks
import DZFoundation
import RSCore
import RSWeb
import UIKit
import WidgetKit

@MainActor var appDelegate: AppDelegate!

@main
@MainActor
final class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate,
    UnreadCountProvider
{
    private let backgroundTaskDispatchQueue = DispatchQueue(label: "BGTaskScheduler")

    private var waitBackgroundUpdateTask = UIBackgroundTaskIdentifier.invalid
    private var syncBackgroundUpdateTask = UIBackgroundTaskIdentifier.invalid

    var shuttingDown = false {
        didSet {
            if self.shuttingDown {
                ArticleStatusSyncTimer.shared.stop()
            }
        }
    }

    var unreadCount = 0 {
        didSet {
            if self.unreadCount != oldValue {
                postUnreadCountDidChangeNotification()
                self.updateBadge()
            }
        }
    }

    var isSyncArticleStatusRunning = false
    var isWaitingForSyncTasks = false

    override init() {
        super.init()
        appDelegate = self

        // Start iCloud account monitoring BEFORE AccountManager to ensure status is known
        iCloudAccountMonitor.shared.start()

        AccountManager.shared.start()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.unreadCountDidChange(_:)),
            name: .UnreadCountDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.accountRefreshDidFinish(_:)),
            name: .AccountRefreshDidFinish,
            object: nil
        )
    }

    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?
    )
        -> Bool
    {
        AppDefaults.registerDefaults()

        registerBackgroundTasks()
        CacheCleaner.purgeIfNecessary()
        initializeDownloaders()
        initializeHomeScreenQuickActions()

        DispatchQueue.main.async {
            self.unreadCount = AccountManager.shared.unreadCount
            // Force the badge to update on launch.
            self.updateBadge()
        }

        UNUserNotificationCenter.current().requestAuthorization(options: [.badge, .sound, .alert]) { granted, _ in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }

        UNUserNotificationCenter.current().delegate = self
        UserNotificationManager.shared.start()

        NetworkMonitor.shared.start()
        ExtensionContainersFile.shared.start()
        ExtensionFeedAddRequestFile.shared.start()

        #if DEBUG
        ArticleStatusSyncTimer.shared.update()
        #endif

        return true
    }

    func application(
        _: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Task { @MainActor in
            self.resumeDatabaseProcessingIfNecessary()
            await AccountManager.shared.receiveRemoteNotification(userInfo: userInfo)
            self.suspendApplication()
            completionHandler(.newData)
        }
    }

    func applicationWillTerminate(_: UIApplication) {
        self.shuttingDown = true
    }

    func applicationDidEnterBackground(_: UIApplication) {
        self.updateBadge()
        IconImageCache.shared.emptyCache()
    }

    private func updateBadge() {
        assert(self.unreadCount == AccountManager.shared.unreadCount)
        UNUserNotificationCenter.current().setBadgeCount(self.unreadCount)
    }

    // MARK: Notifications

    @objc
    func unreadCountDidChange(_ note: Notification) {
        if note.object is AccountManager {
            self.unreadCount = AccountManager.shared.unreadCount
        }
    }

    @objc
    func accountRefreshDidFinish(_: Notification) {
        AppDefaults.shared.lastRefresh = Date()
    }

    // MARK: - API

    func manualRefresh(errorHandler: @escaping @Sendable (Error) -> Void) {
        for connectedScene in UIApplication.shared.connectedScenes.compactMap({ $0.delegate as? SceneDelegate }) {
            connectedScene.cleanUp(conditional: true)
        }
        AccountManager.shared.refreshAllWithoutWaiting(errorHandler: errorHandler)
    }

    func resumeDatabaseProcessingIfNecessary() {
        if AccountManager.shared.isSuspended {
            AccountManager.shared.resumeAll()
            DZLog("Application processing resumed.")
        }
    }

    func prepareAccountsForBackground() {
        self.updateBadge()
        ExtensionFeedAddRequestFile.shared.suspend()
        ArticleStatusSyncTimer.shared.invalidate()
        scheduleBackgroundFeedRefresh()
        syncArticleStatus()
        WidgetDataEncoder.shared?.encode()
        waitForSyncTasksToFinish()
        IconImageCache.shared.emptyCache()
    }

    func prepareAccountsForForeground() {
        self.updateBadge()
        ExtensionFeedAddRequestFile.shared.resume()
        ArticleStatusSyncTimer.shared.update()

        if let lastRefresh = AppDefaults.shared.lastRefresh {
            if Date() > lastRefresh.addingTimeInterval(15 * 60) {
                AccountManager.shared.refreshAllWithoutWaiting(errorHandler: ErrorHandler.log)
            } else {
                AccountManager.shared.syncArticleStatusAllWithoutWaiting()
            }
        } else {
            AccountManager.shared.refreshAllWithoutWaiting(errorHandler: ErrorHandler.log)
        }
    }

    nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.list, .banner, .badge, .sound])
    }

    nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Wrapper to safely transfer non-Sendable values to MainActor
        struct UnsafeSendable<T>: @unchecked Sendable {
            let value: T
        }

        let wrappedResponse = UnsafeSendable(value: response)
        let wrappedCompletionHandler = UnsafeSendable(value: completionHandler)

        Task { @MainActor in
            let response = wrappedResponse.value
            let userInfo = response.notification.request.content.userInfo

            switch response.actionIdentifier {
            case UserNotificationManager.ActionIdentifier.markAsRead:
                handleMarkAsRead(userInfo: userInfo)
            case UserNotificationManager.ActionIdentifier.markAsStarred:
                handleMarkAsStarred(userInfo: userInfo)
            default:
                if let sceneDelegate = response.targetScene?.delegate as? SceneDelegate {
                    sceneDelegate.handle(response)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        sceneDelegate.coordinator.dismissIfLaunchingFromExternalAction()
                    }
                }
            }
            wrappedCompletionHandler.value()
        }
    }
}

// MARK: App Initialization

extension AppDelegate {
    private func initializeDownloaders() {
        let tempDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let imagesFolderURL = tempDir.appendingPathComponent("Images")
        try! FileManager.default.createDirectory(
            at: imagesFolderURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    private func initializeHomeScreenQuickActions() {
        let unreadTitle = NSLocalizedString("First Unread", comment: "First Unread")
        let unreadIcon = UIApplicationShortcutIcon(systemImageName: "chevron.down.circle")
        let unreadItem = UIApplicationShortcutItem(
            type: AppConstants.shortcutFirstUnread,
            localizedTitle: unreadTitle,
            localizedSubtitle: nil,
            icon: unreadIcon,
            userInfo: nil
        )

        let searchTitle = NSLocalizedString("Search", comment: "Search")
        let searchIcon = UIApplicationShortcutIcon(systemImageName: "magnifyingglass")
        let searchItem = UIApplicationShortcutItem(
            type: AppConstants.shortcutShowSearch,
            localizedTitle: searchTitle,
            localizedSubtitle: nil,
            icon: searchIcon,
            userInfo: nil
        )

        let addTitle = NSLocalizedString("Add Feed", comment: "Add Feed")
        let addIcon = UIApplicationShortcutIcon(systemImageName: "plus")
        let addItem = UIApplicationShortcutItem(
            type: AppConstants.shortcutShowAdd,
            localizedTitle: addTitle,
            localizedSubtitle: nil,
            icon: addIcon,
            userInfo: nil
        )

        UIApplication.shared.shortcutItems = [addItem, searchItem, unreadItem]
    }
}

// MARK: Go To Background

extension AppDelegate {
    private func waitForSyncTasksToFinish() {
        guard !self.isWaitingForSyncTasks, UIApplication.shared.applicationState == .background else { return }

        self.isWaitingForSyncTasks = true

        self.waitBackgroundUpdateTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.completeProcessing(true)
            }
            DZLog("Accounts wait for progress terminated for running too long.")
        }

        DispatchQueue.main.async { [weak self] in
            self?.waitToComplete { [weak self] suspend in
                self?.completeProcessing(suspend)
            }
        }
    }

    private func waitToComplete(completion: @escaping (Bool) -> Void) {
        guard UIApplication.shared.applicationState == .background else {
            DZLog("App came back to foreground, no longer waiting.")
            completion(false)
            return
        }

        if
            AccountManager.shared.refreshInProgress || self.isSyncArticleStatusRunning || WidgetDataEncoder.shared?
                .isRunning ?? false
        {
            DZLog("Waiting for sync to finish…")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.waitToComplete(completion: completion)
            }
        } else {
            DZLog("Refresh progress complete.")
            completion(true)
        }
    }

    private func completeProcessing(_ suspend: Bool) {
        if suspend {
            self.suspendApplication()
        }
        UIApplication.shared.endBackgroundTask(self.waitBackgroundUpdateTask)
        self.waitBackgroundUpdateTask = UIBackgroundTaskIdentifier.invalid
        self.isWaitingForSyncTasks = false
    }

    private func syncArticleStatus() {
        guard !self.isSyncArticleStatusRunning else { return }

        self.isSyncArticleStatusRunning = true

        self.syncBackgroundUpdateTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            Task { @MainActor [weak self] in
                self?.completeSyncProcessing()
            }
            DZLog("Accounts sync processing terminated for running too long.")
        }

        Task { @MainActor in
            await AccountManager.shared.syncArticleStatusAll()
            self.completeSyncProcessing()
        }
    }

    private func completeSyncProcessing() {
        self.isSyncArticleStatusRunning = false
        UIApplication.shared.endBackgroundTask(self.syncBackgroundUpdateTask)
        self.syncBackgroundUpdateTask = UIBackgroundTaskIdentifier.invalid
    }

    private func suspendApplication() {
        guard UIApplication.shared.applicationState == .background else { return }

        AccountManager.shared.suspendNetworkAll()
        AccountManager.shared.suspendDatabaseAll()

        CoalescingQueue.standard.performCallsImmediately()
        for scene in UIApplication.shared.connectedScenes {
            if let sceneDelegate = scene.delegate as? SceneDelegate {
                sceneDelegate.suspend()
            }
        }

        DZLog("Application processing suspended.")
    }
}

// MARK: Background Tasks

extension AppDelegate {
    /// Register all background tasks.
    private func registerBackgroundTasks() {
        // Register background feed refresh.
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: AppConstants.backgroundFeedRefreshIdentifier,
            using: nil
        ) { task in
            self.performBackgroundFeedRefresh(with: task as! BGAppRefreshTask)
        }
    }

    /// Schedules a background app refresh based on `AppDefaults.refreshInterval`.
    private func scheduleBackgroundFeedRefresh() {
        // We send this to a dedicated serial queue because as of 11/05/19 on iOS 13.2 the call to the
        // task scheduler can hang indefinitely.
        self.backgroundTaskDispatchQueue.async {
            do {
                let request = BGAppRefreshTaskRequest(identifier: AppConstants.backgroundFeedRefreshIdentifier)
                request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
                try BGTaskScheduler.shared.submit(request)
            } catch {
                DZLog("Could not schedule app refresh: \(error.localizedDescription)")
            }
        }
    }

    /// Performs background feed refresh.
    /// - Parameter task: `BGAppRefreshTask`
    /// - Warning: As of Xcode 11 beta 2, when triggered from the debugger this doesn't work.
    private func performBackgroundFeedRefresh(with task: BGAppRefreshTask) {
        self.scheduleBackgroundFeedRefresh() // schedule next refresh

        DZLog("Performing background refresh.")

        Task { @MainActor in
            if AccountManager.shared.isSuspended {
                AccountManager.shared.resumeAll()
            }
            await AccountManager.shared.refreshAll(errorHandler: ErrorHandler.log)
            if !AccountManager.shared.isSuspended {
                self.suspendApplication()
                DZLog("Background refresh completed.")
                task.setTaskCompleted(success: true)
            }
        }

        // set expiration handler
        task.expirationHandler = { [weak task] in
            DZLog("Background refresh terminated for running too long.")
            DispatchQueue.main.async {
                self.suspendApplication()
                task?.setTaskCompleted(success: false)
            }
        }
    }
}

// Handle Notification Actions

extension AppDelegate {
    private func handleMarkAsRead(userInfo: [AnyHashable: Any]) {
        self.handleStatusNotification(userInfo: userInfo, statusKey: .read)
    }

    private func handleMarkAsStarred(userInfo: [AnyHashable: Any]) {
        self.handleStatusNotification(userInfo: userInfo, statusKey: .starred)
    }

    private func handleStatusNotification(userInfo: [AnyHashable: Any], statusKey: ArticleStatus.Key) {
        guard
            let articlePathUserInfo = userInfo[UserInfoKey.articlePath] as? [AnyHashable: Any],
            let accountID = articlePathUserInfo[ArticlePathKey.accountID] as? String,
            let articleID = articlePathUserInfo[ArticlePathKey.articleID] as? String else
        {
            return
        }

        self.resumeDatabaseProcessingIfNecessary()

        guard let account = AccountManager.shared.existingAccount(accountID: accountID) else {
            assertionFailure("Expected account with \(accountID)")
            DZLog("No account with accountID \(accountID) found from status notification")
            return
        }

        guard let singleArticleSet = try? account.fetchArticles(.articleIDs([articleID])) else {
            assertionFailure("Expected article with \(articleID)")
            DZLog("No article with articleID found \(articleID) from status notification")
            return
        }

        assert(singleArticleSet.count == 1)
        account.markArticles(singleArticleSet, statusKey: statusKey, flag: true) { _ in }

        Task { @MainActor in
            try? await account.syncArticleStatus()
            self.prepareAccountsForBackground()
            self.suspendApplication()
        }
    }
}

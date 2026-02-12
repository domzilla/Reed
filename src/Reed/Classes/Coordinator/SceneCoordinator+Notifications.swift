//
//  SceneCoordinator+Notifications.swift
//  Reed
//

import UIKit

extension SceneCoordinator {
    @objc
    func unreadCountDidInitialize(_ notification: Notification) {
        guard notification.object is DataStore else {
            return
        }

        if self.isReadFeedsFiltered {
            rebuildBackingStores()
        }
    }

    @objc
    func unreadCountDidChange(_: Notification) {
        // We will handle the filtering of unread feeds in unreadCountDidInitialize after they have all be calculated
        guard DataStore.shared.areUnreadCountsInitialized else {
            return
        }

        queueRebuildBackingStores()
    }

    @objc
    func statusesDidChange(_: Notification) {
        updateUnreadCount()
    }

    @objc
    func containerChildrenDidChange(_: Notification) {
        if timelineFetcherContainsAnyPseudoFeed() || timelineFetcherContainsAnyFolder() {
            fetchAndMergeArticlesAsync(animated: true) {
                self.mainTimelineViewController?.reinitializeArticles(resetScroll: false)
                self.rebuildBackingStores()
            }
        } else {
            rebuildBackingStores()
        }
    }

    @objc
    func batchUpdateDidPerform(_: Notification) {
        rebuildBackingStores()
    }

    @objc
    func displayNameDidChange(_ note: Notification) {
        rebuildBackingStores()

        // Reload the cell for the object whose display name changed
        if let object = note.object, let indexPath = indexPathFor(object as AnyObject) {
            self.mainFeedCollectionViewController.collectionView.reloadItems(at: [indexPath])
        }
    }

    @objc
    func userDidAddFeed(_ notification: Notification) {
        guard let feed = notification.userInfo?[UserInfoKey.feed] as? Feed else {
            return
        }
        self.discloseFeed(feed, animations: [.scroll, .navigation])
    }

    func userDefaultsDidChange() {
        self.sortDirection = AppDefaults.shared.timelineSortDirection
        self.groupByFeed = AppDefaults.shared.timelineGroupByFeed
    }

    @objc
    func dataStoreDidDownloadArticles(_ note: Notification) {
        guard let feeds = note.userInfo?[DataStore.UserInfoKey.feeds] as? Set<Feed> else {
            return
        }

        let shouldFetchAndMergeArticles = timelineFetcherContainsAnyFeed(feeds) ||
            timelineFetcherContainsAnyPseudoFeed()
        if shouldFetchAndMergeArticles {
            queueFetchAndMergeArticles()
        }
    }

    @objc
    func willEnterForeground(_: Notification) {
        // Don't interfere with any fetch requests that we may have initiated before the app was returned to the
        // foreground.
        // For example if you select Next Unread from the Home Screen Quick actions, you can start a request before we
        // are
        // in the foreground.
        if !self.fetchRequestQueue.isAnyCurrentRequest {
            queueFetchAndMergeArticles()
        }
    }

    /// Updates navigation bar subtitles in response to feed selection, unread count changes,
    /// `combinedRefreshProgressDidChange` notifications, and a timed refresh every
    /// 60s.
    ///
    /// Subtitles are handled differently on iPhone and iPad.
    ///
    /// `MainFeedViewController`
    /// - When refreshing: Feeds will display "Updating..." on both iPhone and iPad.
    /// - When refreshed: Feeds will display "Updated <#relative_time#>" on both iPhone and iPad.
    ///
    /// `MainTimelineViewController`
    /// - Where the unread count for the timeline is > 0, this is displayed on both iPhone and iPad.
    /// - If the timeline count is 0, the iPhone follows the same logic as `MainFeedViewController`
    /// - Specific to iPad, if the unread count is 0, the iPad will not display a subtitle. The refresh text
    /// will generally be visible in the sidebar and there's no need to display it twice.
    ///
    /// - Parameter note: Optional `Notification`
    @objc
    func updateNavigationBarSubtitles(_: Notification?) {
        let progress = DataStore.shared.combinedRefreshProgress

        if progress.isComplete {
            if let lastArticleFetchEndTime = DataStore.shared.lastArticleFetchEndTime {
                if Date.now > lastArticleFetchEndTime.addingTimeInterval(60) {
                    let relativeDateTimeFormatter = RelativeDateTimeFormatter()
                    relativeDateTimeFormatter.dateTimeStyle = .named
                    let refreshed = relativeDateTimeFormatter.localizedString(
                        for: lastArticleFetchEndTime,
                        relativeTo: Date()
                    )
                    let localizedRefreshText = NSLocalizedString("Updated %@", comment: "Updated")
                    let refreshText = NSString.localizedStringWithFormat(
                        localizedRefreshText as NSString,
                        refreshed
                    ) as String

                    // Update Feeds with Updated text
                    self.mainFeedCollectionViewController?.navigationItem.subtitle = refreshText

                    // If unread count > 0, add unread string to timeline
                    if let _ = timelineFeed, timelineUnreadCount > 0 {
                        let localizedUnreadCount = NSLocalizedString("%i Unread", comment: "14 Unread")
                        let unreadCount = NSString.localizedStringWithFormat(
                            localizedUnreadCount as NSString,
                            self.timelineUnreadCount
                        ) as String
                        self.mainTimelineViewController?.updateNavigationBarSubtitle(unreadCount)
                    } else {
                        // When unread count == 0, iPhone timeline displays Updated Just Now; iPad is blank
                        if UIDevice.current.userInterfaceIdiom == .phone {
                            self.mainTimelineViewController?.updateNavigationBarSubtitle(refreshText)
                        } else {
                            self.mainTimelineViewController?.updateNavigationBarSubtitle("")
                        }
                    }
                } else {
                    // Use 'Updated Just Now' while <60s have passed since refresh.
                    self.mainFeedCollectionViewController?.navigationItem.subtitle = NSLocalizedString(
                        "Updated Just Now",
                        comment: "Updated Just Now"
                    )

                    // If unread count > 0, add unread string to timeline
                    if let _ = timelineFeed, timelineUnreadCount > 0 {
                        let localizedUnreadCount = NSLocalizedString("%i Unread", comment: "14 Unread")
                        let refreshTextWithUnreadCount = NSString.localizedStringWithFormat(
                            localizedUnreadCount as NSString,
                            self.timelineUnreadCount
                        ) as String
                        self.mainTimelineViewController?.updateNavigationBarSubtitle(refreshTextWithUnreadCount)
                    } else {
                        // When unread count == 0, iPhone timeline displays Updated Just Now; iPad is blank
                        if UIDevice.current.userInterfaceIdiom == .phone {
                            self.mainTimelineViewController?.updateNavigationBarSubtitle(NSLocalizedString(
                                "Updated Just Now",
                                comment: "Updated Just Now"
                            ))
                        } else {
                            self.mainTimelineViewController?.updateNavigationBarSubtitle("")
                        }
                    }
                }
            } else {
                self.mainFeedCollectionViewController?.navigationItem.subtitle = ""
                // If unread count > 0, add unread string to timeline
                if let _ = timelineFeed, timelineUnreadCount > 0 {
                    let localizedUnreadCount = NSLocalizedString("%i Unread", comment: "14 Unread")
                    let refreshTextWithUnreadCount = NSString.localizedStringWithFormat(
                        localizedUnreadCount as NSString,
                        self.timelineUnreadCount
                    ) as String
                    self.mainTimelineViewController?.updateNavigationBarSubtitle(refreshTextWithUnreadCount)
                } else {
                    // When unread count == 0, iPhone timeline displays Updated Just Now; iPad is blank
                    if UIDevice.current.userInterfaceIdiom == .phone {
                        self.mainTimelineViewController?.updateNavigationBarSubtitle(NSLocalizedString(
                            "Updated Just Now",
                            comment: "Updated Just Now"
                        ))
                    } else {
                        self.mainTimelineViewController?.updateNavigationBarSubtitle("")
                    }
                }
            }
        } else {
            // Updating in progress, apply to both iPhone and iPad Feeds.
            self.mainFeedCollectionViewController?.navigationItem.subtitle = NSLocalizedString(
                "Updating...",
                comment: "Updating..."
            )
        }

        self.scheduleNavigationBarSubtitleUpdate()
    }

    func scheduleNavigationBarSubtitleUpdate() {
        if self.isNavigationBarSubtitleRefreshScheduled {
            return
        }
        self.isNavigationBarSubtitleRefreshScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
            self?.isNavigationBarSubtitleRefreshScheduled = false
            self?.updateNavigationBarSubtitles(nil)
        }
    }
}

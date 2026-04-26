# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- Unified modal search opened from a toolbar button, available on both the main feed (global scope) and the timeline (scoped to the current feed).
- Folder picker now offers a "+" button to create a new folder inline, which is then auto-selected.

### Changed
- Search results open the article directly inside the search modal instead of bouncing back through the timeline.
- The timeline navigation bar now shows the current feed or smart feed name and icon instead of a generic "Timeline" label.
- The "show read" filter is now a single global toggle that applies to both feeds and articles.
- Feed inspector now exposes dedicated copy and open buttons for the home page and feed URLs.

### Fixed
- Fixed a crash on iPad caused by CloudKit account change notifications arriving on a background queue.
- Fixed the feed list filter button styling so it matches the timeline filter button when active.
- "Move to Folder" now correctly moves the feed when a new folder is created from the picker.
- Deleting a folder no longer triggers an assertion crash and works offline.
- Fixed CloudKit sync failing with a "Bad Container" error.
- Widget deep links now open in Reed instead of the upstream app.
- Fixed a recursive crash in the download progress tracker.
- The "Updated" timestamp in the navigation bar now refreshes after a sync.
- CloudKit sync errors no longer permanently block future refreshes.
- Fixed an infinite recursion crash on launch.

### Removed
- Removed the Timeline Customizer screen; icon size and preview line count are now chosen automatically based on screen size.
- Simplified the feed context menu by removing redundant "Open Home Page", "Copy Feed URL", and "Copy Home Page URL" actions, and dropping the "Mark All as Read" confirmation dialog.

## [January 2026]

### Added
- Move feeds to a different folder.
- Article navigation buttons and an Appearance setting.
- Settings button on the main feed toolbar.

### Changed
- Renamed the "iCloud" section header to "Feeds".
- iCloud is now optional, with local-first operations.
- The timeline stays open after marking all as read.

### Fixed
- Feed name now updates in the sidebar after renaming via the inspector.
- Fixed a crash in CloudKit sync when no pending items exist.
- Fixed a crash when adding a feed or folder.
- Fixed remaining layout issues from the storyboard migration.

### Removed
- Removed the "Confirm Mark All as Read" setting.
- Removed the Help section and "Add NNW News Feed" entry from Settings.

## [December 2025]

### Added
- State restoration so the app reopens where you left off.

### Changed
- Tuned the Sepia theme styling.

### Fixed
- Fixed a Settings crash after theme removal.
- Fixed a black screen on launch.
- Fixed unread counts not displaying correctly.
- Fixed OPML detection by file extension.

### Removed
- Removed default feeds.
- Removed theme bundles.

## [November 2025]

### Added
- NewsBlur account support.
- Improved feed discovery.
- "Clear" button on the name text field.

### Changed
- Switched to modern network reachability monitoring.
- Now requires iOS 26.

### Fixed
- Fixed article link being cleared incorrectly.
- Refresh no longer runs on the main thread.

### Removed
- Removed the "Liquid Glass display" compatibility flag.

## [October 2025]

### Added
- Markdown rendering in articles.
- Faster HTML stripping (5x to 75x faster).
- AppleScript support for getting articles from folders.

### Changed
- Article previews now show up to 300 characters.
- Web view now appears when navigation commits, reducing flashes of blank content.
- Responses are cached for at least 10 minutes to be kinder to feed publishers.
- 4xx responses are cached for 53 hours instead of just the app session.
- Smarter, faster image discovery for articles.

### Fixed
- Fixed crossed permalinks and external links from Daring Fireball.
- Fixed relative home page URLs in Atom feeds.
- Fixed AppleScript access to articles inside folders.
- Fixed a crash when adding a folder.
- Fixed multiple-selection support for "Copy Article URL".
- Fixed the app icon unread count badge updating on foreground/background transitions.

## [September 2025]

### Added
- Option to disable JavaScript on iOS.
- Localised device names.

### Changed
- Sidebar is now the first toolbar item by default.
- Improved the explanation text on the Accounts settings pane.

### Fixed
- Fixed context menu preview glitches.
- Fixed the keyboard reappearing after dismissal.
- Fixed dragging into an empty account.
- Fixed root author element handling in Atom feeds.
- Fixed a missing iCloud Drive error dialog on iOS.
- Fixed the app icon unread badge on launch.
- Fixed several launch and window crashes.
- Fixed underlines on linked images.
- Improved feed discovery in pages without a `<body>` tag.

### Removed
- Removed support for multiple scenes.

## [August 2025]

### Added
- Custom title and subtitle views in the timeline.

### Changed
- Timeline Customizer now uses the new cells.
- Switched to semibold from bold for selected styling.

### Fixed
- Fixed favicon scaling for some sites.
- Fixed unread count alignment and bold-when-selected styling.
- Fixed timeline sort order.
- Fixed the folder count appearing on load.

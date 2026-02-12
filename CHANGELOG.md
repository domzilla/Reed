# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- Centralized `AppConstants` for all app-wide identifiers (CloudKit container, app group, shortcuts, background tasks, activity types, deep link scheme)

### Fixed
- CloudKit sync failing with "Bad Container" error — container ID was constructed as `iCloud.{orgID}.NetNewsWire` instead of `iCloud.net.domzilla.reed`
- Widget deep links using `nnw://` scheme instead of `reed://`
- Open in Browser activity type still referencing `com.rancharo.NetNewsWire-Evergreen`
- Assertion crash in `DownloadProgress.completeTasks()` — recursive `selectForProcessing()` called `completeTask()` more times than tasks were added
- "Updated" timestamp in navbar never updating — DownloadSession.downloadSessionDidComplete() was never called because updateDownloadProgress() had its body commented out upstream
- CloudKit sync errors could permanently deadlock syncProgress, silently blocking all future refreshes for the app session
- Infinite recursion crash on launch — `DataStore.startManager()` observed `UnreadCountDidInitialize` from itself, causing a re-post loop that overflowed the stack

### Changed
- Replaced all NetNewsWire references with Reed throughout codebase (file headers, OPML export comments, Share Extension title, variable names)
- Removed multi-account legacy layer: ~15 typealiases (`Account`, `AccountType`, `AccountError`, `AccountManager`, `AccountBehavior`), ~10 backward-compat extension shims (`.accountID`, `.account`, `.behaviors`), and notification aliases
- Replaced all `Account`/`account` references with canonical `DataStore`/`dataStore` names across ~30 source files
- Simplified `markArticles()` from multi-account `DispatchGroup` pattern to single `defaultDataStore` call
- Renamed `AccountRefreshTimer` → `AutoRefreshTimer`, `LocalAccountRefresher` → `FeedRefresher`
- Renamed `ExtensionAccount` → `ExtensionDataStore` in Share Extension (preserving on-disk JSON keys for backward compat)
- Consolidated `SmartFeedDelegate` protocol into direct `SmartFeed` configuration — eliminated 5 delegate files, SmartFeed now takes identifier/name/fetchType/icon/closure directly
- Replaced `DataStoreManager` singleton with `DataStore.shared` — removed vestigial multi-account manager layer (327 lines), moved manager API directly into `DataStore`
- Converted `MainThreadOperation` subclasses to `async/await` — replaced `CloudKitReceiveStatusOperation`, `CloudKitSendStatusOperation`, `CloudKitRemoteNotificationOperation`, `FetchAllUnreadCountsOperation` with direct async calls; simplified `WebViewProvider` queue management
- Replaced `FetchRequestOperation` + `FetchRequestQueue` operation-based pattern with `Task`-based cancellation — deleted `FetchRequestOperation` (105 LOC), simplified `FetchRequestQueue` to a single `Task<Void, Never>?` with cancel-and-replace semantics

### Removed
- `DataStoreType` enum and all associated dead code — Reed uses CloudKit exclusively, so the `.onMyMac`/`.cloudKit` distinction was unnecessary
- All legacy data store migration code (`migrateFromLegacyDataStores`, `migrateDataStoreData`, `cleanupLegacyDataStoreFolders`)
- Dead `accountLocalPad` and `accountLocalPhone` image assets (only used in the removed `.onMyMac` branch)
- `isDeveloperRestricted` property from Share Extension (was only defined on the removed `DataStoreType`)
- `type` property from `ExtensionDataStore` serialization (always hardcoded to `.cloudKit`)
- `OrganizationIdentifier` and `AppGroup` keys from Info.plist (replaced by `AppConstants` and `SharedConstants`)
- Dead `.x-netnewswire-hide` CSS rule from `core.css` (never wired up in rendering pipeline)
- Dead `AccountBehavior` enum and all behavior-check code paths (`.disallowFeedInRootFolder`, `.disallowFolderManagement`, `.disallowFeedInMultipleFolders`) — behaviors always returned `[]`
- `Container.account` protocol member and default implementation
- Multi-account iteration helpers (`accountAndArticlesDictionary()`, `substituteContainerIfNeeded()`)
- Dead UI classes: `VibrantLabel`, `VibrantButton`, `VibrantBasicTableViewCell`
- Dead cells: `SettingsComboTableViewCell`, `SelectComboTableViewCell` (never instantiated)
- Dead file: `CloudKitWebDocumentation.swift` (stale NNW URL)
- Unused imports: `MessageUI` from `WebViewController`, `SwiftUI` from `SettingsViewController`
- Unused notifications: `InspectableObjectsDidChange`, `WebInspectorEnabledDidChange`
- `SmartFeedDelegate` protocol and 4 delegate files (`StarredFeedDelegate`, `TodayFeedDelegate`, `SearchFeedDelegate`, `SearchTimelineFeedDelegate`)
- `DataStoreManager` class (replaced by `DataStore.shared`)
- 4 `MainThreadOperation` subclasses: `CloudKitReceiveStatusOperation`, `CloudKitSendStatusOperation`, `CloudKitRemoteNotificationOperation`, `FetchAllUnreadCountsOperation`

## [January 2026]

### Added
- Move to Folder functionality for feeds
- Article navigation buttons and Appearance setting
- Missing settings button to main feed toolbar
- Missing Info.plist keys and UserDefaults suite name fix
- NetNewsWire as submodule for RS* modules (pinned to fork point)
- Queuestack integration for issue tracking

### Changed
- Replaced os.Logger and print() with DZFoundation logging
- Migrated to new Xcode project structure
- Migrated from storyboards to programmatic UI
- Renamed Account to DataStore with simplified single iCloud sync
- Renamed 'iCloud' section header to 'Feeds'
- Unified codebase structure and removed macOS abstractions
- Made iCloud optional with local-first operations
- Updated code comments to use consistent terminology
- Stay in timeline after marking all as read

### Fixed
- Feed name not updating in sidebar after rename via Inspector
- Crash in CloudKit sync when no pending items exist
- Swift 6 concurrency errors by changing default actor isolation
- Crash when adding feed or folder
- Remaining layout issues for storyboard parity

### Removed
- Stale Main storyboard reference from build settings
- Confirm Mark All as Read setting
- Help section and Add NNW News Feed from Settings
- Obsolete files and dependencies
- -warnings-as-errors from packages (interferes with main project settings)

## [December 2025]

### Added
- SwiftFormat configuration
- State restoration using UserDefaults
- ArticleSpecifier for saving article references to disk
- Method for fetching a single article (for state restoration)

### Changed
- Consolidated app-specific modules into Shared/
- Replaced bundle identifiers for Reed fork
- Tuned Sepia theme styling

### Fixed
- Settings crash: adjusted row count after theme removal
- Black screen: updated SceneDelegate class name to Reed module
- Unread counts not displaying correctly
- Assets crash that was not using symbol
- Codesign setup and inheritance
- Crash with -1 row indexes (#4861)
- OPML UTI detection by filename extension

### Removed
- Secrets module
- Buildscripts directory
- Theme UI from Settings storyboard
- Default feeds functionality
- Theme bundles
- Phase 2: Sync services, widgets, and features for lightweight Reed
- Phase 1: All macOS-specific code for iOS-only Reed fork

## [November 2025]

### Added
- NewsBlur module
- FeedFinder module
- CloudKitSync module (moved from RSCore)
- Async wrappers to Transport
- Clear button on the name text field
- FMDatabase and FMResultSet categories
- Scripts folder and symbolication scripts

### Changed
- Converted entire codebase to async/await pattern
- Converted ArticlesDatabase, RSDatabase, RSWeb, RSCore, RSParser to approachable concurrency
- Made SyncDatabase an actor
- Used Swift 6.2 tools and Swift 6 language mode
- Made AccountManager, FaviconDownloader, UserNotificationManager, ArticleStatusSyncTimer singletons
- Renamed WebFeed class to Feed
- Renamed Feed to SidebarItem (#4752)
- Renamed WebFeedMetadata to FeedMetadata (#4754)
- Replaced Reachability with modern NWPathMonitor
- Coalesced Feedly models into single FeedlyModel.swift
- Converted AppAssets to shared Assets struct
- Simplified MainThreadOperation (class instead of protocol)
- Required macOS and iOS 26

### Fixed
- Various Swift 6 concurrency issues throughout codebase
- AppleScript implementation concurrency errors
- Refresh progress task counting in ReaderAPI
- Article.link not being set to nil (#4828)
- Build script issues (filtered spurious Core Data messages)
- Refresh feeds running on main thread

### Removed
- Technotes menu item from Help menu
- References to MAC_APP_STORE
- Unused TickMarkSlider
- Unused RSCoreTests
- Deliberate crash when failing to delete folder
- UIDesignRequiresCompatibility for Liquid Glass display

## [October 2025]

### Added
- RSMarkdown module for Markdown rendering
- Markdown support to RSS parser (source:markdown)
- Markdown column to articles table
- Shared DownloadCache for URLSessions
- LastCheckDate to feed metadata
- ConditionalGetInfoDate tracking
- Special case FeedSpecifier and timing features
- Faster strippingHTML implementation in C (5x-75x faster)
- Scripting support for getting articles from folders
- Function to write multiple URLs to clipboard
- Shared cloudKitLogger

### Changed
- Made Article a reference type (improves scrolling performance)
- Replaced OSLog with Logger throughout codebase
- Show web view after navigation commit instead of didFinish (#4030)
- Cache responses for 10+ minutes to be kind to feed publishers (#4700)
- Cache 4xx responses for 53 hours instead of app session (#4700)
- Drop conditional GET info every 8 days for buggy servers
- Set sidebar collapse state synchronously (no visible collapsing on launch)
- Find suitable images in one pass instead of three
- Check unread count instead of database fetch for mark-all-read (#4630)
- Increased article preview to 300 characters (#4782)
- Turn on treat-warnings-as-errors

### Fixed
- CloudKit deprecations
- iCloud progress not reaching zero tasks
- Daring Fireball's crossed permalinks and external links
- Relative home page URLs in Atom feeds
- Container hierarchy for AppleScript selectedArticles() (#4218)
- AppleScript access to articles in feeds in folders (#4412)
- Crash when adding a folder
- Multiple selection for copy-article-url commands (#3681)
- App icon unread count badge on foreground/background (#4365)

### Removed
- Flaky testFeedOPML tests
- Scripts requiring keystroke-sending

## [September 2025]

### Added
- Shared WebViewConfiguration
- Shared HelpURL for help URLs
- Shared AddCloudKitAccount.swift for common error handling
- Error recovery to UIViewController.presentError extension
- hasiCloudAccount computed var
- Option to disable JavaScript on iOS devices (#4323)
- Device name localization (#4322)
- Formatter for unread counts (#3892)
- Script to clean up whitespace-only lines

### Changed
- Made Sidebar first toolbar item by default
- Moved Open Application Support Folder to Help menu (#4800)
- Renamed URL.reparingIfRequired to URL.encodeSpacesIfNeeded
- Updated window color palette only on setting changes
- Separated code of conduct into separate file (#4035)
- Improved explanation text on Accounts settings pane
- Mark classes as final when possible (#4751)

### Fixed
- Context preview glitches (#4794)
- Keyboard reappearing after dismissal
- Drag into empty account (#3825)
- Root author element in Atom feeds (#2797)
- iCloud Drive missing error dialog on iOS (#4785)
- Horizontal white bar in account inspectors (#3765)
- App icon unread count badge on launch (#4537)
- Window force-unwrap crash (#3827)
- Images as links underlining (#4574)
- Feed finder scoring for index.xml and JSON (#4136)
- GUID permalink with space detection (#1230)
- Feed finding in HTML pages without body tag (#4521)

### Removed
- Support for multiple scenes (#4798)
- Canvas code (CORS failures)
- Debug UIResponder code

## [August 2025]

### Added
- Custom title/subtitle views for timeline (#4722)
- NSMutableParagraphStyle truncation support

### Changed
- Timeline Customizer uses new cells (#4723)
- Made state restoration explicit (legacy vs secure)
- Use semibold instead of bold for styling (#4718)
- Embedded indicator in add button (#4716)

### Fixed
- Rendering bug with some favicons (proper scaling)
- Unread trailing alignment
- Sort order (#4727)
- Avatar display and removed unused code
- Paragraph style adjustments (#4719)
- Folder count appearing on load (#4717)
- Unread count bold when selected (#4718)
- Various UI issues (#4714, #4715)

### Removed
- Old timeline cell code (#4723)
- MainFeedViewController from Storyboard
- willChangeTo displayMode method
- MacStateRestoration.md (no longer needed)
- Spaces from file names


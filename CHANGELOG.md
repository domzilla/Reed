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
- Removed 3 dead forward declarations in `NSData+RSParser.m` and fixed 2 compiler warnings (`unused binding in ShareFolderPickerController`, `unnecessary nonisolated(unsafe) in DataStore`)
- Infinite recursion crash on launch — `DataStore.startManager()` observed `UnreadCountDidInitialize` from itself, causing a re-post loop that overflowed the stack

### Changed
- Renamed 5 ObjC extension files — `FMDatabase+RDExtras` → `FMDatabase+Reed`, `FMResultSet+RDExtras` → `FMResultSet+Reed`, `NSString+RDDatabase` → `NSString+Database`, `NSData+RDParser` → `NSData+Parser`, `NSString+RDParser` → `NSString+Parser`; updated all category names, imports, and bridging header
- Dissolved `UserInfoKey` enum — split into `AppConstants.NotificationKey` (feed, url, articlePath) and `AppConstants.StateRestorationKey` (window/filter/sidebar state keys); removed 7 dead constants
- Restructured `Classes/` directory hierarchy — created `App/`, `Coordinator/`, `Protocols/`, `Utilities/`, `UIComponents/`, `Icons/` directories; dissolved `Core/` (redistributed to Extensions, Utilities, Protocols, UIComponents, App); cleaned up `Extensions/` (moved non-extension types to Articles, Icons, Protocols, UIComponents); standardized extension naming to `+Reed` suffix; renamed directories with spaces (`Collection View Cells/` → `Cells/`, `Related Objects/` → `RelatedObjects/`); flattened `ArticlesDatabase/Extensions/` into parent; extracted FMDB to `src/Reed/Vendor/FMDB/`; merged `UIImage+ImageProcessing` + `UIImage+Extensions` → `UIImage+Reed`, `URL+Core` + `URL+Web` → `URL+Reed`; removed empty `ArticlesDatabase/Operations/`
- Decomposed `MainFeedCollectionViewController.swift` (1,501 LOC) into 2 extension files — `+ContextMenus` (context menu builders, all action builders, rename/delete flows, AddFeedFolderViewControllerDelegate) and `+KeyboardCommands` (keyboard shortcut handlers); main file retains class declaration, properties, view lifecycle, collection view data source/delegate, cell configuration, notifications, and small delegate conformances
- Decomposed `MainTimelineViewController.swift` (1,376 LOC) into 3 extension files — `+Actions` (all article action builders, share dialog, action helpers), `+Search` (UISearchControllerDelegate, UISearchResultsUpdating, UISearchBarDelegate), and `+Notifications` (all notification handlers); main file retains class declaration, properties, view lifecycle, table view delegate/swipe actions, data source, toolbar, and state management
- Decomposed `DataStore.swift` (1,612 LOC) into 6 focused extension files — `DataStore+ArticleFetching`, `DataStore+UnreadCounts`, `DataStore+FeedFolderOperations`, `DataStore+Notifications`, `DataStore+ContainerTree`, `DataStore+ManagerAPI`; main file retains class declaration, init, properties, protocol conformances, and lifecycle
- Renamed all RS-prefixed (Ranchero Software) identifiers across 123 files — ObjC types/functions/methods use `RD` prefix, Swift types have prefix removed; renamed module folders `RSCore`→`Core`, `RSDatabase`→`Database`, `RSParser`→`Parser`, `RSWeb`→`Web`, `RSTree`→`Tree`
- Replaced all `os.Logger` usage with `DZFoundation` (`DZLog`) across 5 files — `DownloadSession`, `Downloader`, `RSImage`, `DatabaseQueue`, `HTMLMetadataDownloader`
- Removed all `#if os(macOS)` conditional compilation paths and `RSImage` typealias across 8 files — app is iOS-only
- Inlined 11 trivial extension files into their callers — `Calendar+RSCore`, `NotificationCenter+RSCore`, `Bundle+RSCore`, `UIActivityViewController+Extras`, `AddFeedDefaultContainer`, `CacheCleaner`, `UIView+RSCore`, `UICollectionView+RSCore`, `UIPageViewController+RSCore`, `UIFont+RSCore`, `String+RSParser` each had 1–2 call sites and didn't justify separate files
- Merged 3 extension file pairs — `UIViewController+RSCore` into `UIViewController+Extras`, `ExtensionContainers+DataStore` into `ExtensionContainersFile+MainApp`, `CGImage+RSCore` into `IconImage.swift`
- Inlined 8 single-use wrapper types — `RSMarkdown`, `RSSParser`, `AtomParser`, `InitialFeedDownloader`, `JSONUtilities`, `OPMLExporter`, `HTTPMethod`, `RSScreen` were each trivial enums/structs wrapping a single function call, used exactly once
- Merged 10 tiny types into their sole consumers — `TopLevelRepresentedObject` into `Node`, `MainFeedRowIdentifier`/`WrapperScriptMessageHandler`/`CroppingPreviewParameters`/`SingleArticleFetcher`/`FaviconGenerator` into their respective callers, `Blocks.swift` typealias into `RSImage.swift`, `JSONTypes.swift` into `JSONFeedParser`
- Merged 4 file pairs — `TitleActivityItemSource` into `ArticleActivityItemSource`, `OpenInSafariActivity` into `FindInArticleActivity`, `HTTPResponseHeader` into `HTTPRequestHeader`, `NonIntrinsicLabel` into `NonIntrinsicImageView`
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
- Merged 6 trivially small files into logical neighbors — `PseudoFeed` protocol into `SmartFeed.swift`, `AppNotifications` into `SceneCoordinator.swift`, `SyncConstants` into `SyncStatus.swift`, `DatabaseObject+Database` into `RelatedObjectsMap+Database.swift`, `MainTimelineDataSource` into `MainTimelineViewController.swift`, `ErrorHandler` into `UIViewController+Extras.swift` + inlined at call sites
- Consolidated `AuthorAvatarDownloader` into `ImageDownloader` — avatar caching, scaling, and notification logic now lives directly in `ImageDownloader`, eliminating the intermediate NotificationCenter hop between the two classes
- Decomposed `CloudKitSyncProvider` (1,439 LOC) into 4 focused extension files — `+FeedOperations` (feed CRUD and cloud sync pipeline), `+FolderOperations` (folder CRUD), `+ArticleStatus` (article status sync and change storage), `+PendingOperations` (offline queue and operation processing); main file retains class declaration, init, lifecycle, and refresh orchestration
- Inlined vendor RS* modules (RSCore, RSParser, RSWeb, RSDatabase, RSTree, RSMarkdown) into the app target — removed git submodule, 6 package targets, and all cross-module `import`/`public` boilerplate; ObjC headers now go through the bridging header
- Removed dead `TransportError` pattern matching from `DataStoreError` (nothing throws `TransportError` after removing `Transport.swift`)
- Removed 3 unused `AppDefaults` properties (`isDeveloperBuild`, `refreshInterval`, `currentThemeName`) and supporting constant `defaultThemeName`
- Deleted orphaned `RefreshInterval.swift` — only consumer was the removed `refreshInterval` property
- Dissolved `readFilterEnabledTable` computed property — callers now use `sidebarItemsHidingReadArticles` `Set` directly instead of converting to `[SidebarItemIdentifier: Bool]` dict

### Removed
- Dead notification `DataStoreRefreshDidBegin` — posted but never observed
- Dead methods from `ArticleArray`: `anyArticleIsStarred()`, `anyArticleIsUnstarred()`, `anyArticleIsReadAndCanMarkUnread()`, `articlesForIndexes(_:)`, `representSameArticlesInSameOrder(as:)`
- Dead methods from `URL+Reed`: `appendingQueryItem(_:)`, `appendingQueryItems(_:)`, `preparedForOpeningInBrowser()`, `absoluteStringWithHTTPOrHTTPSPrefixRemoved()` and fileprivate `String.stringByRemovingCaseInsensitivePrefix(_:)` helper
- Dead call chain from `Node+Reed`: `[Node].sortedAlphabetically()` and `Node.nodesSortedAlphabetically()`
- Dead method `UIImage.tinted(color:)` and always-false `debugLoggingEnabled` constant with 9 dead `if` branches in `UIImage+Reed`
- Dead method `ArticleStatusSyncTimer.fireOldTimer()`
- Dead initializer `HTTPConditionalGetInfo.init?(headers:)`
- 6 unused HTTP header constants: `HTTPRequestHeader.authorization`, `.contentType`, `HTTPResponseHeader.contentType`, `.location`, `.link`, `.date`
- 3 unused `NetworkMonitor` properties: `connectionType`, `isExpensive`, `isConstrained`
- ~57 unused `HTTPResponseCode` constants (kept 8 that are referenced)
- Stale `@IBDesignable` annotations from `ArticleSearchBar`, `IconView`, `InteractiveLabel` (project uses programmatic UI only)
- Legacy state restoration migration: `StateRestorationInfo.init(legacyState:)` (~90 LOC), `AppDefaults.didMigrateLegacyStateRestorationInfo` property and UserDefaults key
- 17 unnecessary extension files deleted — 3 entirely dead code (`UniformTypeIdentifiers+RSCore`, `FileManager+RSCore`, `URLComponents+RSWeb`), 11 inlined into callers, 3 merged into existing files
- Dead code: `IconImage.appIcon`, `UIImage.appIconImage`, `NSAttributedString.adding(font:)`, `Bundle.appName`, `Bundle.buildNumber`
- Dead vendor module files: 10 unused files deleted (Transport.swift, TransportJSON.swift, MacWebBrowser.swift, Dictionary+RSWeb.swift, HTTPDateInfo.swift, HTTPLinkPagingInfo.swift, MimeType.swift, String+RSWeb.swift, URLRequest+RSWeb.swift, UIStoryboard+RSCore.swift, ModalNavigationController.swift, RSParser/Exports.swift)
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


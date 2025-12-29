# NetNewsWire Codebase Analysis

> Comprehensive analysis of the NetNewsWire RSS reader codebase for the Reed fork project.

---

## ✅ Phase 1 Complete: macOS Code Removal

**Status:** Completed on 2025-12-29

Phase 1 has been successfully completed. The codebase is now iOS-only. The following changes were made:

### Deleted Directories
- `Mac/` (~80 files) - All macOS-specific UI and features
- `AppleScript/` (~10 files) - macOS AppleScript integration
- `Appcasts/` (2 files) - Sparkle update feeds

### Deleted Files
**Shared/**
- `SmartFeedPasteboardWriter.swift` - macOS pasteboard API
- `SendToMarsEditCommand.swift` - macOS MarsEdit integration
- `SendToMicroBlogCommand.swift` - macOS Micro.blog integration

**Modules/**
- `RSCoreResources/` directory - macOS resources (xib files)
- `NSOutlineView+RSTree.swift` - macOS NSOutlineView extension
- `SendToBlogEditorApp.swift` - macOS Apple Events
- `NSSharingService+Extension.h/m` - macOS sharing service

### Cleaned Conditionals
All `#if os(macOS)` and `#if canImport(AppKit)` conditionals have been removed from:
- 13 files in `Shared/`
- 6 files in `Modules/`

### Package Updates
- `RSCore/Package.swift` - Removed RSCoreResources target, set iOS-only platform
- `RSCore.h` - Removed macOS header import

### xcconfig Files Deleted
- `NetNewsWire_macapp_target.xcconfig`
- `NetNewsWire_shareextension_target.xcconfig`
- `NetNewsWire_safariextension_target.xcconfig`
- `NetNewsWireTests_target.xcconfig`

### Build Verification
✅ iOS app builds successfully for iOS Simulator
✅ No `import AppKit` remaining in Shared/ or Modules/
✅ No `#if os(macOS)` remaining in Shared/ or Modules/

**Note:** macOS targets in the Xcode project still need to be manually removed.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Project Structure](#2-project-structure)
3. [Build Targets](#3-build-targets)
4. [Dependencies](#4-dependencies)
5. [Supported Sync Services](#5-supported-sync-services)
6. [Features Catalog](#6-features-catalog)
7. [Extensions & Widgets](#7-extensions--widgets)
8. [Architecture](#8-architecture)
9. [Data Models](#9-data-models)
10. [Database Layer](#10-database-layer)
11. [Networking Layer](#11-networking-layer)
12. [iOS vs macOS Code Separation](#12-ios-vs-macos-code-separation)
13. [Recommendations for Reed](#13-recommendations-for-reed)

---

## 1. Project Overview

**NetNewsWire** is a free and open-source RSS reader for macOS and iOS. It's a mature, professionally maintained project with:

- **Platform Support**: macOS 15.0+ and iOS 15.0+
- **Architecture**: Multi-platform with shared business logic
- **Language**: Swift 6 (with Swift Package Manager modules)
- **UI Framework**: AppKit (macOS) and UIKit (iOS) - no SwiftUI at app level
- **Database**: SQLite via custom FMDatabase wrapper
- **License**: MIT License

---

## 2. Project Structure

```
Reed/
├── NetNewsWire.xcodeproj/     # Main Xcode project
├── iOS/                        # iOS app target source code
│   ├── Account/               # Account management UI
│   ├── Add/                   # Feed addition UI
│   ├── Article/               # Article viewing (16 subdirectories)
│   ├── Inspector/             # Inspector panel
│   ├── IntentsExtension/      # Siri Intents extension
│   ├── MainFeed/              # Feed list UI
│   ├── MainTimeline/          # Article timeline UI
│   ├── Settings/              # Settings/Preferences
│   ├── ShareExtension/        # Share sheet support
│   ├── UIKit Extensions/      # Custom UIKit helpers
│   ├── Resources/             # Storyboards and assets
│   ├── AppDelegate.swift
│   ├── SceneDelegate.swift
│   ├── SceneCoordinator.swift
│   └── AppDefaults.swift
├── Mac/                        # macOS app target source code
│   ├── About/                 # About window
│   ├── CrashReporter/         # Crash reporting
│   ├── Inspector/             # Inspector panel
│   ├── MainWindow/            # Main app window (16 subdirectories)
│   ├── Preferences/           # Preferences dialog (8 subdirectories)
│   ├── SafariExtension/       # Safari extension
│   ├── Scripting/             # AppleScript support (13 subdirectories)
│   ├── ShareExtension/        # Share extension
│   ├── Resources/             # Assets and resources
│   ├── AppDelegate.swift
│   └── AppDefaults.swift
├── Shared/                     # Shared code (iOS + macOS)
│   ├── Activity/              # User activity tracking
│   ├── Article Rendering/     # HTML article rendering (11 subdirectories)
│   ├── Article Extractor/     # Reader mode content extraction
│   ├── ArticleStyles/         # CSS styling and themes
│   ├── Commands/              # Command handling
│   ├── Exporters/             # OPML export
│   ├── Extensions/            # Swift extensions (11 subdirectories)
│   ├── ExtensionPoints/       # Third-party app integration
│   ├── Favicons/              # Favicon management
│   ├── Images/                # Image assets
│   ├── Importers/             # Feed/OPML import
│   ├── Resources/             # Shared resources and themes
│   ├── Settings/              # Shared settings
│   ├── ShareExtension/        # Shared share extension code
│   ├── SmartFeeds/            # Smart feed logic (12 subdirectories)
│   ├── Timeline/              # Timeline display
│   ├── Timer/                 # Refresh timers
│   ├── Tree/                  # Tree data structure UI
│   ├── UserNotifications/     # Notification management
│   └── Widget/                # Shared widget code
├── Modules/                    # Swift Package modules (14 packages)
│   ├── Account/               # Account system abstraction
│   ├── Articles/              # Article model
│   ├── ArticlesDatabase/      # Article storage
│   ├── CloudKitSync/          # CloudKit synchronization
│   ├── FeedFinder/            # Feed discovery
│   ├── NewsBlur/              # NewsBlur service
│   ├── RSCore/                # Core utilities
│   ├── RSDatabase/            # Database abstraction
│   ├── RSMarkdown/            # Markdown support
│   ├── RSParser/              # Feed parsing
│   ├── RSTree/                # Tree data structure
│   ├── RSWeb/                 # Web utilities
│   ├── Secrets/               # API credentials
│   └── SyncDatabase/          # Sync state management
├── Widget/                     # iOS Widget extension
│   ├── Widget Views/          # SwiftUI widget components
│   ├── Shared Views/          # Reusable widget views
│   ├── Resources/             # Widget assets
│   ├── WidgetBundle.swift
│   └── TimelineProvider.swift
├── Intents/                    # Siri Intents definitions
├── Tests/                      # Test suites
├── Technotes/                  # Documentation
├── AppleScript/                # Example AppleScript scripts
├── Appcasts/                   # Sparkle update feeds
├── buildscripts/               # Build and CI scripts
├── xcconfig/                   # Xcode build configurations
└── scripts/                    # Utility scripts
```

---

## 3. Build Targets

### macOS Targets (3)
| Target | Type | Description |
|--------|------|-------------|
| `NetNewsWire` | Application | Main macOS application |
| `NetNewsWire Share Extension` | App Extension | macOS Share extension |
| `Subscribe to Feed` | Safari Extension | Safari toolbar button |

### iOS Targets (6)
| Target | Type | Description |
|--------|------|-------------|
| `NetNewsWire-iOS` | Application | Main iOS application |
| `NetNewsWire iOS Share Extension` | App Extension | iOS Share extension |
| `NetNewsWire iOS Intents Extension` | App Extension | Siri Shortcuts support |
| `NetNewsWire iOS Widget Extension` | Widget Extension | Home/Lock screen widgets |
| `NetNewsWire-iOSTests` | Unit Tests | iOS unit tests |
| `NetNewsWireTests` | Unit Tests | macOS unit tests |

---

## 4. Dependencies

### External Dependencies (Remote SPM)

| Package | Version | Purpose | Platform |
|---------|---------|---------|----------|
| **Sparkle-Binary** | 2.0.1 | macOS app updater framework | macOS only |
| **PLCrashReporter** | 1.11.0 | Crash reporting and diagnostics | macOS only |
| **Zip** | (pinned rev) | ZIP file compression/decompression | Both |
| **swift-markdown** | 0.7.3 | Apple's Markdown parsing library | Both |
| **swift-cmark** | 0.7.1 | CommonMark implementation (transitive) | Both |

### Internal Modules (14 Local Swift Packages)

#### Foundation Modules (No Dependencies)
| Module | Purpose |
|--------|---------|
| `RSCore` | Utility extensions for Foundation/AppKit |
| `RSDatabase` | SQLite wrapper (FMDatabase) |
| `RSTree` | Tree/hierarchy utilities |
| `Secrets` | API credentials management |

#### Parsing & Data Modules
| Module | Dependencies | Purpose |
|--------|--------------|---------|
| `RSMarkdown` | swift-markdown | Markdown support |
| `RSParser` | RSMarkdown | Feed parsing (RSS, Atom, JSON Feed) |
| `RSWeb` | RSParser, RSCore | Network requests, HTML parsing |
| `FeedFinder` | RSWeb, RSParser, RSCore | Feed URL discovery |
| `Articles` | RSCore | Article model |
| `ArticlesDatabase` | Articles, RSParser, RSDatabase, RSCore | Article persistence |
| `SyncDatabase` | Articles, RSCore, RSDatabase | Sync state tracking |
| `NewsBlur` | Secrets, RSWeb, RSParser, RSCore | NewsBlur API integration |
| `CloudKitSync` | RSCore | CloudKit synchronization |
| `Account` | (aggregates most modules) | Account system abstraction |

### Dependency Graph
```
                    ┌─────────────────┐
                    │     Account     │ (Top-level)
                    └────────┬────────┘
                             │
    ┌────────────────────────┼────────────────────────┐
    │                        │                        │
┌───┴───┐  ┌─────────────┐  ┌┴────────────┐  ┌───────┴───────┐
│NewsBlur│  │ArticlesDB   │  │CloudKitSync│  │  SyncDatabase │
└───┬───┘  └──────┬──────┘  └─────────────┘  └───────────────┘
    │             │
┌───┴───┐  ┌──────┴──────┐
│ RSWeb │  │   Articles  │
└───┬───┘  └──────┬──────┘
    │             │
┌───┴───┐  ┌──────┴──────┐
│RSParser│  │   RSCore   │ (Foundation)
└───┬───┘  └─────────────┘
    │
┌───┴─────┐
│RSMarkdown│
└───┬─────┘
    │
┌───┴──────────┐
│swift-markdown│ (External)
└──────────────┘
```

---

## 5. Supported Sync Services

### Account Types (9 Total)

| Type | Name | Implementation | Sync Method |
|------|------|----------------|-------------|
| `onMyMac` | On My Mac/iPhone | `LocalAccountDelegate` | No sync (local only) |
| `cloudKit` | iCloud | `CloudKitAccountDelegate` | Apple CloudKit |
| `feedly` | Feedly | `FeedlyAccountDelegate` | OAuth 2.0 + REST API |
| `feedbin` | Feedbin | `FeedbinAccountDelegate` | REST API |
| `newsBlur` | NewsBlur | `NewsBlurAccountDelegate` | Custom API |
| `freshRSS` | FreshRSS | `ReaderAPIAccountDelegate` | Reader API |
| `inoreader` | Inoreader | `ReaderAPIAccountDelegate` | Reader API |
| `bazQux` | BazQux | `ReaderAPIAccountDelegate` | Reader API |
| `theOldReader` | The Old Reader | `ReaderAPIAccountDelegate` | Reader API |

### Account Organization (UI Grouping)

```
Local Accounts
└── On My Mac/Device (no sync)

iCloud Account
└── iCloud (CloudKit sync)

Web Accounts
├── Feedly (OAuth)
├── Feedbin (API)
├── NewsBlur (API)
├── BazQux (Reader API)
├── Inoreader (Reader API)
└── The Old Reader (Reader API)

Self-Hosted Accounts
└── FreshRSS (Reader API)
```

### Account Behaviors

| Behavior | Applies To |
|----------|------------|
| `disallowFeedCopyInRootFolder` | Feedbin |
| `disallowFeedInRootFolder` | Feedly, FreshRSS |
| `disallowFeedInMultipleFolders` | All Reader API services |
| `disallowOPMLImports` | All Reader API services |
| `disallowMarkAsUnreadAfterPeriod(31)` | Feedly (31-day limit) |

### Implementation Files

```
Modules/Account/Sources/Account/
├── LocalAccount/
│   └── LocalAccountDelegate.swift
├── CloudKit/
│   └── CloudKitAccountDelegate.swift (11 files)
├── Feedly/
│   └── FeedlyAccountDelegate.swift (43+ files)
├── Feedbin/
│   └── FeedbinAccountDelegate.swift (11 files)
├── NewsBlur/
│   └── NewsBlurAccountDelegate.swift (2 files)
└── ReaderAPI/
    └── ReaderAPIAccountDelegate.swift (9 files, supports 4 variants)
```

---

## 6. Features Catalog

### Core Features (Shared - iOS & macOS)

| Feature | Description | Location |
|---------|-------------|----------|
| **Feed Management** | Add feeds, organize into folders | `Shared/Tree/`, `Shared/Importers/` |
| **Article Reading** | Full article display via WebKit | `Shared/Article Rendering/` |
| **Article Extractor** | Reader mode (clean content extraction) | `Shared/Article Extractor/` |
| **Article Themes** | Multiple built-in themes | `Shared/ArticleStyles/` |
| **Mark Read/Unread** | Track read status | `Shared/Commands/` |
| **Star/Favorite** | Mark articles as starred | `Shared/Commands/` |
| **Smart Feeds** | Unread, Today, Starred | `Shared/SmartFeeds/` |
| **OPML Import/Export** | Import/export feed lists | `Shared/Importers/`, `Shared/Exporters/` |
| **Favicons** | Download and cache feed icons | `Shared/Favicons/` |
| **Notifications** | System notifications for new articles | `Shared/UserNotifications/` |
| **Sharing** | Share articles via system share sheet | `Shared/Activity/` |
| **Background Refresh** | Automatic feed refresh | `Shared/Timer/` |
| **Full-Text Search** | Search articles via FTS5 | `Modules/ArticlesDatabase/` |

### iOS-Only Features

| Feature | Description | Location |
|---------|-------------|----------|
| **Split View** | Master-detail interface | `iOS/MainFeed/`, `iOS/MainTimeline/` |
| **Widgets** | Unread, Today, Starred widgets | `Widget/` |
| **Siri Shortcuts** | Add feeds via Siri | `Intents/`, `iOS/IntentsExtension/` |
| **Share Extension** | Add feeds from Share sheet | `iOS/ShareExtension/` |
| **Touch UI** | Collection view-based interface | `iOS/MainFeed/` |

### macOS-Only Features

| Feature | Description | Location |
|---------|-------------|----------|
| **AppleScript** | Full scripting support | `Mac/Scripting/` |
| **Safari Extension** | Subscribe to feeds from Safari | `Mac/SafariExtension/` |
| **Multi-Window** | Multiple windows support | `Mac/MainWindow/` |
| **Preferences Window** | Multi-tab preferences | `Mac/Preferences/` |
| **Keyboard Navigation** | Extensive keyboard shortcuts | `Shared/Resources/GlobalKeyboardShortcuts.plist` |
| **Crash Reporter** | Built-in crash reporting | `Mac/CrashReporter/` |
| **Drag & Drop** | Reorganize feeds via drag | `Mac/MainWindow/Sidebar/` |
| **OPML Import UI** | File picker for OPML | `Mac/MainWindow/OPML/` |

### Built-in Article Themes

| Theme | Description |
|-------|-------------|
| Default | Standard theme |
| Promenade | Alternative styling |
| Appanoose | Alternative styling |
| Sepia | Warm, paper-like appearance |
| Hyperlegible | High-readability font |
| NewsFax | Newspaper-style layout |

### Feed Format Support

| Format | Parser |
|--------|--------|
| RSS 2.0 | `RSSParser` (SAX-based) |
| Atom | `AtomParser` (SAX-based) |
| JSON Feed | `JSONFeedParser` |
| RSS-in-JSON | `RSSInJSONParser` |

---

## 7. Extensions & Widgets

### iOS Widget Extension

**Target**: `NetNewsWire iOS Widget Extension`

| Widget | Kind ID | Sizes | Description |
|--------|---------|-------|-------------|
| Unread | `com.ranchero.NetNewsWire.UnreadWidget` | Medium, Large | Unread article count and list |
| Today | `com.ranchero.NetNewsWire.TodayWidget` | Medium, Large | Today's articles |
| Starred | `com.ranchero.NetNewsWire.StarredWidget` | Medium, Large | Starred articles |

**Location**: `Widget/Widget Views/`

### iOS Intents Extension

**Target**: `NetNewsWire iOS Intents Extension`

| Intent | Description |
|--------|-------------|
| `AddWebFeedIntent` | Add a web feed via Siri |

**Location**: `iOS/IntentsExtension/`, `Intents/`

### iOS Share Extension

**Target**: `NetNewsWire iOS Share Extension`

| Feature | Description |
|---------|-------------|
| Add feeds from Share menu | Extract feed URLs from shared content |
| Folder selection | Choose destination folder |
| Account selection | Choose target account |

**Location**: `iOS/ShareExtension/`

### macOS Share Extension

**Target**: `NetNewsWire Share Extension`

| Feature | Description |
|---------|-------------|
| Add feeds from Share menu | Share from Safari and other apps |
| Folder/account picker | Popup menu selection |

**Location**: `Mac/ShareExtension/`

### macOS Safari Extension

**Target**: `Subscribe to Feed`

| Feature | Description |
|---------|-------------|
| Toolbar button | One-click feed subscription |
| Feed detection | JavaScript injection for feed URL detection |
| Custom URL scheme | `x-netnewswire-feed:` handling |

**Location**: `Mac/SafariExtension/`

### App Groups

| Platform | App Group |
|----------|-----------|
| iOS | `group.$(ORGANIZATION_IDENTIFIER).NetNewsWire.iOS` |
| macOS | `group.$(ORGANIZATION_IDENTIFIER).NetNewsWire-Evergreen` |

---

## 8. Architecture

### Architectural Patterns

#### 1. Delegate-Based Account Abstraction

```
Account (Main interface)
  └─ AccountDelegate (Protocol)
     ├─ LocalAccountDelegate
     ├─ CloudKitAccountDelegate
     ├─ FeedbinAccountDelegate
     ├─ FeedlyAccountDelegate
     ├─ NewsBlurAccountDelegate
     └─ ReaderAPIAccountDelegate
```

#### 2. MainActor Isolation

- Almost everything is `@MainActor`
- Background operations return to main thread via async/await
- No locks used (except Mutex for ArticleStatus)

#### 3. Notification-Based Reactivity

```swift
// Key Notifications
AccountRefreshDidBegin
AccountRefreshDidFinish
AccountDidDownloadArticles
StatusesDidChange
UnreadCountDidChange
DisplayNameDidChange
ChildrenDidChange
```

#### 4. Container Protocol

```swift
protocol Container {
    var topLevelFeeds: Set<Feed> { get }
    var folders: Set<Folder>? { get }
    func flattenedFeeds() -> Set<Feed>
}
// Implemented by: Account, Folder
```

### Module Architecture

```
┌─────────────────────────────────────────────────────┐
│                    iOS/macOS Apps                   │
│  (SceneCoordinator/AppDelegate, ViewControllers)    │
└────────────────────┬────────────────────────────────┘
                     │
┌─────────────────────────────────────────────────────┐
│              Shared UI Resources                    │
│ (ArticleStyles, SmartFeeds, Timeline, Rendering)    │
└────────────────────┬────────────────────────────────┘
                     │
┌─────────────────────────────────────────────────────┐
│           Business Logic Modules                    │
│  Account, Articles, ArticlesDatabase, SyncDatabase  │
└────────────────────┬────────────────────────────────┘
                     │
┌─────────────────────────────────────────────────────┐
│         Foundation Modules (No Dependencies)        │
│  RSParser, RSWeb, RSDatabase, RSCore, RSTree        │
└─────────────────────────────────────────────────────┘
```

### UI Architecture

#### iOS (UIKit-Based)

```
SceneCoordinator (Central coordinator)
├── RootSplitViewController
├── MainFeedCollectionViewController (sidebar)
├── MainTimelineViewController (article list)
└── ArticleViewController (detail)
```

#### macOS (AppKit-Based)

```
AppDelegate
├── MainWindowController
│   ├── SidebarViewController
│   ├── TimelineViewController
│   └── DetailViewController
└── PreferencesWindowController
```

### Coding Principles

From `Technotes/CodingGuidelines.md`:

1. **No data loss** > No crashes > No bugs > Performance > Productivity
2. **No subclasses** - Use composition, protocols, delegates
3. **Final classes everywhere** - Prevents accidental inheritance
4. **All notifications on main queue** - Consistent threading
5. **Pure Swift** - Avoid @objc except for AppKit integration
6. **Small objects** - Break large classes into logical pieces
7. **No KVO** - Use notifications and didSet instead

---

## 9. Data Models

### Account Model Hierarchy

```swift
// Account.swift (~1441 lines)
@MainActor
class Account: Container {
    var type: AccountType
    var feeds: Set<Feed>
    var folders: Set<Folder>
    var articlesDatabase: ArticlesDatabase
    var delegate: AccountDelegate
    var metadata: AccountMetadata
}

// Feed.swift (~340 lines)
@MainActor
final class Feed {
    var feedID: String
    var url: String
    var name: String?
    var editedName: String?
    var conditionalGetInfo: HTTPConditionalGetInfo?
    var metadata: FeedMetadata
}

// Folder.swift
@MainActor
final class Folder: Container {
    var name: String
    var feeds: Set<Feed>
}
```

### Article Models

```swift
// Article.swift (~131 lines)
struct Article: Sendable {
    let articleID: String
    let feedID: String
    let uniqueID: String
    let title: String?
    let contentHTML: String?
    let contentText: String?
    let markdown: String?
    let rawURL: String?
    let rawExternalURL: String?
    let summary: String?
    let rawImageLink: String?
    let datePublished: Date?
    let dateModified: Date?
    let authors: Set<Author>?
    let status: ArticleStatus
}

// ArticleStatus.swift (~100 lines)
final class ArticleStatus: Sendable {
    let articleID: String
    let dateArrived: Date
    private let mutex: Mutex<StatusData>
    var read: Bool { get set }
    var starred: Bool { get set }
}
```

### Storage Per Account

```
AccountFolder/
├── DB.sqlite3           # Articles database
├── Sync.sqlite3         # Sync status (for syncing accounts)
├── Settings.plist       # Account metadata
├── Subscriptions.opml   # Feed/folder list
└── FeedMetadata.plist   # Additional feed attributes
```

---

## 10. Database Layer

### ArticlesDatabase

**Location**: `Modules/ArticlesDatabase/`

| Table | Purpose |
|-------|---------|
| `articles` | Feed content with searchRowID for FTS |
| `statuses` | Article read/starred status |
| `authors` | Author data |
| `search` | Full-text search index (FTS5) |

**Key Operations**:
- `fetchArticles(feedID/feedIDs/articleIDs)`
- `fetchUnreadArticles`, `fetchStarredArticles`, `fetchTodayArticles`
- `updateAsync` - Merge parsed items into database
- `markAsync` - Update article status
- Full-text search via FTS5

**Retention Policies**:
- `feedBased` - Local/iCloud (keep what feed contains)
- `syncSystem` - Service accounts (keep per service policy)

### SyncDatabase

**Location**: `Modules/SyncDatabase/`

| Table | Purpose |
|-------|---------|
| `syncStatus` | Pending read/starred changes |

**Key Operations**:
- `insertStatuses`, `selectForProcessing`
- `selectPendingReadStatusArticleIDs`
- `selectPendingStarredStatusArticleIDs`

---

## 11. Networking Layer

### RSWeb Module

**Features**:
- Conditional GET support (ETag, Last-Modified)
- HTTP redirect following
- Cookie/authentication support
- User-Agent handling

**Download Architecture**:
```
OneShotDownload (convenience)
  ↓
DownloadSession
  └─ DownloadSessionDelegate
```

### Feed Fetching Flow

1. `LocalAccountRefresher` iterates feeds
2. `DownloadSession` fetches URL with conditional headers
3. Response passed to `FeedParser`
4. `HTTPConditionalGetInfo` updated for next request
5. Stored in `Feed.conditionalGetInfo`

### Account-Specific APIs

| Service | Authentication | API Type |
|---------|----------------|----------|
| Feedbin | HTTP Basic | REST JSON |
| Feedly | OAuth 2.0 | REST JSON |
| NewsBlur | Custom | REST JSON |
| Reader API | Token | Reader API |
| CloudKit | iCloud | CloudKit |

---

## 12. iOS vs macOS Code Separation

### Platform-Specific Code

| Directory | Platform | Purpose |
|-----------|----------|---------|
| `iOS/` | iOS only | UIKit-based UI, iOS-specific features |
| `Mac/` | macOS only | AppKit-based UI, macOS-specific features |
| `Widget/` | iOS only | WidgetKit widgets |
| `Shared/` | Both | Business logic, rendering, utilities |
| `Modules/` | Both | Core data/sync frameworks |

### iOS-Only Files (~50+ files)

```
iOS/
├── AppDelegate.swift
├── SceneDelegate.swift
├── SceneCoordinator.swift
├── AppDefaults.swift
├── MainFeed/
├── MainTimeline/
├── Article/
├── Settings/
├── Add/
├── Account/
├── Inspector/
├── ShareExtension/
├── IntentsExtension/
└── UIKit Extensions/
```

### macOS-Only Files (~80+ files)

```
Mac/
├── AppDelegate.swift
├── AppDefaults.swift
├── Browser.swift
├── MainWindow/
├── Preferences/
├── Inspector/
├── ShareExtension/
├── SafariExtension/
├── Scripting/
├── About/
└── CrashReporter/
```

### macOS-Only Features to Remove

| Feature | Location | Effort |
|---------|----------|--------|
| AppleScript support | `Mac/Scripting/` (13 subdirs) | High |
| Safari Extension | `Mac/SafariExtension/` | Medium |
| Sparkle updater | External dependency | Low |
| PLCrashReporter | External dependency | Low |
| Preferences window | `Mac/Preferences/` | Medium |
| Multi-window | `Mac/MainWindow/` | High |
| macOS share extension | `Mac/ShareExtension/` | Low |
| OPML import/export UI | `Mac/MainWindow/OPML/` | Low |
| Keyboard shortcuts | Shared file, macOS-specific | Low |

---

## 13. Recommendations for Reed

### Phase 1: Remove macOS Code

1. **Delete macOS directories**:
   - `Mac/` (entire directory)
   - `AppleScript/` (entire directory)
   - `Mac/SafariExtension/` (Safari extension)

2. **Remove macOS targets from Xcode project**:
   - NetNewsWire (macOS app)
   - NetNewsWire Share Extension (macOS)
   - Subscribe to Feed (Safari extension)
   - NetNewsWireTests (macOS tests)

3. **Remove macOS-only dependencies**:
   - Sparkle-Binary (app updater)
   - PLCrashReporter (crash reporting)

4. **Clean up xcconfig files**:
   - Remove `NetNewsWire_macapp_target.xcconfig`
   - Remove `NetNewsWire_shareextension_target.xcconfig`
   - Remove `NetNewsWire_safariextension_target.xcconfig`
   - Remove `NetNewsWireTests_target.xcconfig`

### Phase 2: Simplify for Lightweight RSS Reader

**Consider removing sync services** (if not needed):
- Feedly (`Modules/Account/Sources/Account/Feedly/` - 43+ files)
- Feedbin (`Modules/Account/Sources/Account/Feedbin/`)
- NewsBlur (`Modules/Account/Sources/Account/NewsBlur/` + `Modules/NewsBlur/`)
- Reader API services (`Modules/Account/Sources/Account/ReaderAPI/`)

**Keep for core functionality**:
- LocalAccountDelegate (on-device storage)
- CloudKitAccountDelegate (optional, for iCloud sync)

**Optional removals for minimal footprint**:
- Article Extractor (reader mode)
- Custom themes (keep only Default)
- Widgets (if not needed)
- Intents Extension (Siri shortcuts)

### Phase 3: Rename and Rebrand

1. **Rename targets**:
   - NetNewsWire-iOS → Reed
   - All extensions with new bundle identifiers

2. **Update App Groups**:
   - Change from `NetNewsWire` to `Reed`

3. **Update assets**:
   - App icons
   - Launch screens
   - About/credits

### Estimated Code Reduction

| Component | Files | Impact |
|-----------|-------|--------|
| Mac/ directory | ~80 files | Remove |
| AppleScript/ | ~10 files | Remove |
| Sparkle/PLCrash | 2 packages | Remove |
| Feedly account | ~43 files | Optional |
| Feedbin account | ~11 files | Optional |
| NewsBlur account | ~10 files | Optional |
| Reader API | ~9 files | Optional |

**Estimated reduction**: 40-60% of codebase (if removing sync services)

---

## Summary

NetNewsWire is a well-architected, mature RSS reader with:

- **Clean separation** between iOS and macOS code
- **Modular architecture** via Swift packages
- **Protocol-based extensibility** for sync services
- **No SwiftUI** (pure UIKit/AppKit)
- **SQLite-based** persistence (no Core Data)

For Reed, the path forward is:
1. Remove all macOS-specific code (~80 files)
2. Remove macOS-only dependencies (Sparkle, PLCrash)
3. Optionally simplify sync services (keep only Local + iCloud)
4. Rebrand and rename

The modular architecture makes this straightforward - the iOS code is largely independent of macOS code, sharing only the `Shared/` and `Modules/` directories.

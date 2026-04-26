# Reed RSS Reader for iOS (NetNewsWire Fork)

## Project Overview
RSS/Atom/JSON Feed reader for iOS. Fork of NetNewsWire with customizations.

## Tech Stack
- **Language**: Swift 6
- **UI Framework**: UIKit
- **Programmatic UI only** - No storyboards or XIBs (except launch screens)
- **IDE**: Xcode
- **Platforms**: iOS
- **Minimum Deployment**: iOS 26.0

## Style & Conventions (MANDATORY)
**Strictly follow** the Swift/SwiftUI style guide: `~/Agents/Style/swift-swiftui-style-guide.md`

## Changelog (MANDATORY)
**All important user facing changes** (fixes, additions, deletions, changes) must be written to CHANGELOG.md.
Changelog format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Localization (MANDATORY)
**Strictly follow** the localization guide: `~/Agents/Guides/localization-guide.md`
- All user-facing strings must be localized
- Follow formality rules per language
- Consistency is paramount

## Additional Guides
- Modern SwiftUI patterns: `~/Agents/Guides/swift-modern-development-guide.md`
- Observable migration: `~/Agents/Guides/swift-observable-migration-guide.md`
- Swift 6 concurrency: `~/Agents/Guides/swift6-concurrency-guide.md`
- Swift 6 migration (compact): `~/Agents/Guides/swift6-migration-compact-guide.md`
- Swift 6 migration (full): `~/Agents/Guides/swift6-migration-full-guide.md`

## Logging (MANDATORY)
This project uses **DZFoundation** (`~/GIT/Libraries/DZFoundation`) for logging.

**All debug logging must use:**
- `DZLog("message")` — General debug output
- `DZErrorLog(error)` — Conditional error logging (only prints if error is non-nil)

```swift
import DZFoundation

DZLog("Starting fetch")       // 🔶 fetchData() 42: Starting fetch
DZErrorLog(error)             // ❌ MyFile.swift:45 fetchData() ERROR: Network unavailable
```

**Do NOT use:**
- `print()` for debug output
- `os.Logger` instances
- `NSLog`

Both functions are no-ops in release builds.

## API Documentation
Local Apple API documentation is available at:
`~/Agents/API Documentation/Apple/`

The `search` binary is located **inside** the documentation folder:
```bash
~/Agents/API\ Documentation/Apple/search --help  # Run once per session
~/Agents/API\ Documentation/Apple/search "view controller" --language swift
~/Agents/API\ Documentation/Apple/search "NSWindow" --type Class
```

## Xcode Project Files (CATASTROPHIC — DO NOT TOUCH)
- **NEVER edit Xcode project files** (`.xcodeproj`, `.xcworkspace`, `project.pbxproj`, `.xcsettings`, etc.)
- Editing these files will corrupt the project — this is **catastrophic and unrecoverable**
- Only the user edits project settings, build phases, schemes, and file references manually in Xcode
- If a file needs to be added to the project, **stop and tell the user** — do not attempt it yourself
- Use `xcodebuild` for building/testing only — never for project manipulation
- **Exception**: Only proceed if the user gives explicit permission for a specific edit
  
## File System Synchronized Groups (Xcode 16+)
This project uses **File System Synchronized Groups** (internally `PBXFileSystemSynchronizedRootGroup`), introduced in Xcode 16. This means:
- The `Classes/` and `Resources/` directories are **directly synchronized** with the file system
- **You CAN freely create, move, rename, and delete files** in these directories
- Xcode automatically picks up all changes — no project file updates needed
- This is different from legacy Xcode groups, which required manual project file edits

**Bottom line:** Modify source files in `Classes/` and `Resources/` freely. Just never touch the `.xcodeproj` files themselves.

## Build & Format Commands
```bash
# Build
xcodebuild -project src/Reed.xcodeproj -scheme "Reed" -destination "generic/platform=iOS Simulator" build

# Clean
xcodebuild -scheme "Reed" clean
```

## Code Formatting (MANDATORY)
**Always run SwiftFormat after a successful build:**
```bash
swiftformat .
```

SwiftFormat configuration is defined in `.swiftformat` at the project root. This enforces:
- 4-space indentation
- Explicit `self.` usage
- K&R brace style
- Trailing commas in collections
- Consistent wrapping rules

**Do not commit unformatted code.**

## Architecture

### UI Framework
- All view controllers use `init()` or `init(style:)` with programmatic setup
- Auto Layout via anchor constraints
- Cells registered programmatically in `viewDidLoad()` or `configureCollectionView()`

### Key Patterns
- `SceneCoordinator` - Central navigation coordinator, injected into view controllers
- `RootSplitViewController` - Triple-column split view (primary/supplementary/secondary)
- Lazy properties for UI elements (replaces IBOutlets)
- `@objc` methods for actions (replaces IBActions)

### Cell Registration Pattern
```swift
override func viewDidLoad() {
    super.viewDidLoad()
    tableView.register(MyCell.self, forCellReuseIdentifier: "MyCell")
}
```

### View Controller Initialization Pattern
```swift
init() {
    super.init(nibName: nil, bundle: nil)
}

// or for table views:
init() {
    super.init(style: .insetGrouped)
}

@available(*, unavailable)
required init?(coder: NSCoder) {
    fatalError("Use init()")
}
```

### CloudKit Sync Pattern (MANDATORY)
All `CloudKitSyncProvider` operations **must** follow this local-first pattern:

1. **Do the local operation first** (modify tree, clear metadata, etc.) — this always succeeds
2. **Check `iCloudAccountMonitor.shared.isAvailable`** before any CloudKit calls
3. **If available**: attempt CloudKit sync; on recoverable errors, queue via `queue*Operation()`; on non-recoverable errors, log but do NOT throw (local state is authoritative)
4. **If not available**: queue the operation for later sync via `queue*Operation()`
5. **Skip CloudKit entirely** if the entity has a `local-` prefixed external ID (not yet synced)

```swift
// Pattern used by createFolder, renameFolder, removeFeed, moveFeed, addFeed, removeFolder:
func someOperation(for dataStore: DataStore, ...) async throws {
    // 1. Local operation first
    dataStore.doLocalChange(...)

    // 2. Guard: need real external ID for CloudKit
    guard let extID = entity.externalID, !extID.hasPrefix("local-") else { return }

    // 3. Check iCloud availability
    if iCloudAccountMonitor.shared.isAvailable {
        do {
            try await feedsZone.doCloudKitOperation(...)
        } catch {
            if iCloudAccountMonitor.isRecoverableError(error) {
                queueSomeOperation(...)
            } else {
                DZLog("iCloud: error (local succeeded): \(error.localizedDescription)")
            }
        }
    } else {
        queueSomeOperation(...)
    }
}
```

Key files: `CloudKitSyncProvider+FeedOperations.swift`, `CloudKitSyncProvider+FolderOperations.swift`, `CloudKitSyncProvider+PendingOperations.swift`

### DownloadProgress Bookkeeping
`DownloadProgress` tracks sync tasks with `addTask()`/`addTasks(_:)` and `completeTask()`/`completeTasks(_:)`. Every `addTask` **must** have exactly one matching `completeTask` on all code paths (success, error, early return). Use `defer { syncProgress.completeTask() }` when possible. Mismatches cause assertion crashes.

---

## Notes
- The style guide emphasizes native SwiftUI patterns over MVVM boilerplate
- Prefer `@Observable` (iOS 17+) over `ObservableObject`
- Use `async/await` and `.task` modifier for async work
- Avoid Combine unless specifically needed
- Always run `swiftformat .` after successful builds before committing
- Coordinator must be set before `window.makeKeyAndVisible()` (for `prefersStatusBarHidden`)
- Actor isolation: wrap background task callbacks in `Task { @MainActor in }`
- iOS 26+: Use `.prominent` instead of deprecated `.done` for bar button style
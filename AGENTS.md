# Reed RSS Reader for iOS (NetNewsWire Fork)

## Project Overview
RSS/Atom/JSON Feed reader for iOS. Fork of NetNewsWire with customizations.

## Tech Stack
- **Language**: Swift
- **UI Framework**: UIKit
- **Programmatic UI only** - No storyboards or XIBs (except launch screens)
- **IDE**: Xcode
- **Platforms**: iOS

## Guides (MANDATORY)
Read `~/Agents/Guides/xcode-project-guide.md` in full before planning or editing anything.

Read these in full before touching the matching code:
- Swift style (`.swift`): `~/Agents/Style/swift-swiftui-style-guide.md`
- Objective-C style (`.h`, `.m`): `~/Agents/Style/objc-style-guide.md`
- Accessibility (UI code, XIBs, storyboards): `~/Agents/Guides/accessibility-guide.md`

## Build Commands
```bash
# Build
xcodebuild -project src/Reed.xcodeproj -scheme "Reed" -destination "generic/platform=iOS Simulator" build

# Clean
xcodebuild -scheme "Reed" clean
```

## Testing (MANDATORY)
No test targets exist in this project.

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

## Notes
- Coordinator must be set before `window.makeKeyAndVisible()` (for `prefersStatusBarHidden`)
- Actor isolation: wrap background task callbacks in `Task { @MainActor in }`
- iOS 26+: Use `.prominent` instead of deprecated `.done` for bar button style

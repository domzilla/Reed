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

### Project Structure
```
src/
  Reed/                      # Main iOS app
    Classes/                 # All Swift source files
      SceneDelegate.swift        # Window/coordinator setup
      SceneCoordinator.swift     # Navigation logic
      RootSplitViewController.swift
      MainFeed/              # Feed list (collection view)
      MainTimeline/          # Article list (table view)
      Article/               # Article detail (web view)
      Settings/              # Settings screens
      Add/                   # Add feed/folder flows
      Inspector/             # Feed inspector
      Articles/              # Article models
      ArticlesDatabase/      # Article persistence
      CloudKitSync/          # iCloud sync
      Commands/              # User commands
      DataStore/             # Data layer
      Exporters/             # Export functionality
      Extensions/            # Swift extensions
      Favicons/              # Favicon handling
      FeedFinder/            # Feed discovery
      Images/                # Image handling
      SmartFeeds/            # Smart feed filters
      SyncDatabase/          # Sync persistence
      Timeline/              # Timeline logic
      Tree/                  # Tree data structure
      UserNotifications/     # Push notifications
      Widget/                # Widget support
    Resources/               # Assets, icons, launch screen
  Shared/                    # Shared code (app + extension)
  ShareExtension/            # Share extension
  Reed.xcodeproj             # Xcode project
vendor/
  NetNewsWire/               # Upstream submodule (RS* modules)
```

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
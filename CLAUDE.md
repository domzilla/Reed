# Reed (NetNewsWire Fork)

RSS/Atom/JSON Feed reader for iOS. Fork of NetNewsWire with customizations.

## Build

```bash
xcodebuild -scheme "NetNewsWire-iOS" -destination "generic/platform=iOS Simulator" build
```

## Architecture

### UI Framework
- **Programmatic UI only** - No storyboards or XIBs (except launch screens)
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
Classes/
  SceneDelegate.swift      # Window/coordinator setup
  SceneCoordinator.swift   # Navigation logic
  RootSplitViewController.swift
  MainFeed/                # Feed list (collection view)
  MainTimeline/            # Article list (table view)
  Article/                 # Article detail (web view)
  Settings/                # Settings screens
  Add/                     # Add feed/folder flows
  Inspector/               # Feed inspector
Modules/
  RSCore/                  # Core utilities
  RSParser/                # Feed parsing
  RSWeb/                   # Network utilities
ShareExtension/            # Share extension
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

## Important Notes

- Coordinator must be set before `window.makeKeyAndVisible()` (for `prefersStatusBarHidden`)
- Actor isolation: wrap background task callbacks in `Task { @MainActor in }`
- iOS 26+: Use `.prominent` instead of deprecated `.done` for bar button style

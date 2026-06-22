# Migration: AppKit-XIB to Pure SwiftUI

## Overview

The app was fully migrated from an AppKit-based architecture (Storyboard/XIB files,
`NSWindowController`, `NSViewController` subclasses, and a storyboard-driven entry
point) to a **pure SwiftUI** UI with a storyboard-free, programmatic app launch.

Every XIB and Storyboard scene that used to drive a window or view controller has
been removed.  Windows are now created in Swift code; views are SwiftUI `View`
structs hosted via `NSHostingController`.

## 1. Storyboard-free Entry Point

### Before

The app relied on `@NSApplicationMain` (or the `NSApplicationMain` attribute in
`Info.plist`) to bootstrap itself and on `Main.storyboard` to create the initial
window.

### After

`AppDelegate` provides its own `main()` entry point and boots the app entirely in
Swift code.

```swift
// AppDelegate.swift
@main
class AppDelegate: NSObject, NSApplicationDelegate {

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
    …
}
```

`NSPrincipalClass` in `Info.plist` still points to `NSApplication`; no storyboard key
(`NSMainStoryboardFile`) exists in the bundle.

---

## 2. Main Window – Programmatic Creation

### Before

`Main.storyboard` contained an `NSWindowController` scene that the system
instantiated automatically on launch, wiring up a toolbar with a segmented control
for tab switching.

### After

`AppDelegate.createAndShowMainWindow()` builds the window entirely in code and
hosts the SwiftUI root view via `NSHostingController`:

```swift
private func createAndShowMainWindow() {
    let window = NSWindow(
        contentRect: NSRect(origin: .zero, size: NSSize(width: 760, height: 480)),
        styleMask: [.titled, .closable, .miniaturizable, .resizable,
                    .fullSizeContentView],
        backing: .buffered,
        defer: false
    )
    window.title = "About This Hack"
    window.minSize = NSSize(width: 680, height: 420)
    window.backgroundColor = .windowBackgroundColor

    let hosting = NSHostingController(
        rootView: ContentView().environmentObject(AppState.shared)
    )
    window.contentViewController = hosting
    window.makeKeyAndOrderFront(nil)
}
```

Window-frame persistence (save/restore position across launches) is handled by
`AppState.saveWindowFrame(_:)` / `savedWindowFrame(for:)` via `UserDefaults`.

## 3. Main Menu – Programmatic Creation

### Before

The application menu and the tab-switching menu items were defined inside
`Main.storyboard` and wired to `AppDelegate` via `@IBAction` / `@IBOutlet`.

### After

`AppDelegate.createMainMenu()` builds the full `NSMenu` hierarchy in Swift code and
is called from `applicationWillFinishLaunching(_:)`:

```swift
func applicationWillFinishLaunching(_ notification: Notification) {
    NSApp.mainMenu = createMainMenu()
}
```

Tab-switching items (Overview ⌘1, Displays ⌘2, Storage ⌘3, Support ⌘4) are added
programmatically with `target = self` so they call the `@IBAction` selectors on
`AppDelegate` without any storyboard outlet.

A **Language** submenu (⌘L) is inserted dynamically after the app menu in
`insertLanguageMenu()`.

## 4. Navigation State – `AppState` and `AppSection`

A lightweight `ObservableObject` singleton replaces the old `WindowController`
segmented-control logic.

```swift
// WindowController.swift  (file kept for historical name; contains only AppState)
enum AppSection: String, CaseIterable, Identifiable {
    case overview, displays, storage, support
    var title: String { … }        // localized
    var systemImage: String { … }  // SF Symbol name
}

class AppState: ObservableObject {
    static let shared = AppState()

    @Published var selectedSection: AppSection? = .overview
    @Published var isDataLoaded = false

    // Window frame persistence helpers …
}
```

`AppDelegate` tab-action methods write to `AppState.shared.selectedSection`; the
SwiftUI view hierarchy observes it via `@EnvironmentObject`.

## 5. Root SwiftUI View – `ContentView` and `FakeSidebarLayout`

### `ContentView`

The SwiftUI root view shows a loading spinner until hardware data is ready, then
switches to the main layout:

```swift
struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.isDataLoaded {
                FakeSidebarLayout()
            } else {
                LoadingView()
            }
        }
        .frame(minWidth: 680, minHeight: 420)
    }
}
```

### `FakeSidebarLayout`

A plain `HStack` with a fixed-width left panel of `Button` rows replaces
`NavigationSplitView`, which had persistent tap-event issues on macOS Tahoe:

```swift
HStack(spacing: 0) {
    // Sidebar – 165 pt wide, tinted background
    VStack(alignment: .leading, spacing: 2) {
        ForEach(AppSection.allCases) { section in
            SidebarRow(section: section,
                       isSelected: appState.selectedSection == section) {
                appState.selectedSection = section
            }
        }
        Spacer()
    }
    .frame(width: 165)
    .background(sidebarBackground)

    Divider()

    // Detail – fills remaining space
    detailView
        .frame(maxWidth: .infinity, maxHeight: .infinity)
}
```

The sidebar rows are plain `Button` views styled with `RoundedRectangle` highlight;
no `List`, `NavigationLink`, or `NavigationSplitView` is involved.

## 6. Replaced AppKit View Controllers

| Old file | Old type | New file | New SwiftUI type |
|---|---|---|---|
| `ViewController.swift` | `NSViewController` (Overview tab) | `ViewController.swift` | `OverviewView` + `OverviewViewModel` |
| `ViewControllerDisplays.swift` | `NSViewController` (Displays tab) | `ViewControllerDisplays.swift` | `DisplaysView` + `DisplaysViewModel` |
| `ViewControllerStorage.swift` | `NSViewController` (Storage tab) | `ViewControllerStorage.swift` | `StorageView` + `StorageViewModel` |
| `ViewControllerSupport.swift` | `NSViewController` (Support tab) | `ViewControllerSupport.swift` | `SupportView` + `SupportLinkButton` |
| `WindowController.swift` | `NSWindowController` | `WindowController.swift` | `AppState` + `AppSection` (no AppKit types) |

All view models expose only plain value or `@Published` properties; there are no
`IBOutlet` or `IBAction` references.

## 7. Settings Window

### Before

`Settings.storyboard` defined a window + view-controller scene.  `AppDelegate`
instantiated it via `NSStoryboard.instantiateController(withIdentifier:)`.

### After

`SettingsWindowController` creates its `NSWindow` in its `convenience init()` and
hosts `SettingsView` (a SwiftUI view) via `NSHostingController`:

```swift
convenience init() {
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0,
                            width: Self.windowWidth,
                            height: Self.contentHeight),
        styleMask: [.titled, .closable, .miniaturizable],
        backing: .buffered,
        defer: false
    )
    window.isReleasedWhenClosed = false
    self.init(window: window)
    performSetupIfNeeded()
}

private func setupSwiftUIContent() {
    let hostingController = NSHostingController(rootView: SettingsView())
    window?.contentViewController = hostingController
}
```

`SettingsView` handles drag-and-drop PNG validation (1024 × 1024) and
`UserDefaults` persistence through `SettingsViewModel`.

## 8. Language Selector Window (new)

A new secondary window allows the user to switch the UI language at runtime
(EN / ES / FR).  It follows the same pattern as the Settings window:

- `LanguageSelectorWindowController` – creates `NSWindow` programmatically,
  centers it on the main window, hosts `LanguageSelectorView` via
  `NSHostingController`.
- `LanguageSelectorView` – SwiftUI `List` + buttons; writes the selection to
  `UserDefaults["AppleLanguages"]` and prompts the user to restart.
- The menu item **Language › Select Language…** (⌘L) is injected by
  `AppDelegate.insertLanguageMenu()`.

## 9. Structured Logging – `ATHLogger`

The preexisting `ATHLogger` utility replaces ad-hoc `print()` calls.

```swift
ATHLogger.info("Window loaded", category: .ui)
ATHLogger.debug("Frame saved: \(frame)", category: .ui)
ATHLogger.error("Failed to open URL", category: .ui)
```

Logs are routed through `os_log` with configurable minimum level (`debug` in
`DEBUG` builds, `info` in release).  Four categories are available: `.ui`,
`.data`, `.hardware`, `.system`.

## 10. Preserved Functionality

The following features were carried over unchanged:

- Custom logo (drag-drop PNG 1024 × 1024 via Settings, `customLogoDidChange` notification, `UserDefaults` persistence)
- Serial-number show/hide toggle
- Tooltips on spec fields (`.help()` modifier)
- Keyboard shortcuts ⌘1–4 for tabs, ⌘, for Settings
- SIP detection via `dlsym("csr_get_active_config")` in Swift (`HCVersion.csrActiveConfig()`)
- Window position persistence (`AppState` helpers)
- Full localization: keys added for spec labels, button
  titles, and log messages
- Temp files cleanup on app termination.

## 11. Files Removed

| Removed artifact | Reason |
|---|---|
| `Main.storyboard` window | Replaced by programmatic `NSWindow` + SwiftUI |
| `Settings.storyboard` | Replaced by `SettingsWindowController` convenience init() |
| `@NSApplicationMain`<br>`NSApplicationMain` Info.plist key | Replaced by `AppDelegate.main()` |
| All `@IBOutlet` / `@IBAction` storyboard wiring | Replaced by SwiftUI bindings and `@EnvironmentObject` |

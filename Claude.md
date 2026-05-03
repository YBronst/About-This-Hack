# About This Hack – Codebase Guide for Claude

## Project Purpose

**About This Hack** is a macOS app that recreates the classic pre-Ventura "About This Mac" window with modern enhancements. It targets both Hackintosh users (PCs running macOS via OpenCore or Clover bootloaders) and real Mac users. It displays hardware info (CPU, RAM, GPU, displays, storage, audio codec), bootloader version, serial number, and support links.

- macOS 13.5 (Ventura) minimum deployment target
- Pure SwiftUI UI (migrated from AppKit/XIB)
- Storyboard-free (AppDelegate bootstraps everything manually)
- Auto-updater via Sparkle framework (SPM dependency)
- Localized into: English (`en`), Spanish (`es`), French (`fr`), Italian (`it`)
<!-- - Transparent/liquid-glass window style (`.ultraThinMaterial` backgrounds) -->

## Tech Stack

| Area | Technology |
|---|---|
| Language | Swift 5 (+ one Objective-C file for SIP reading) |
| UI framework | SwiftUI (macOS 13.5+) |
| App lifecycle | AppKit (`NSApplicationDelegate`, no storyboard) |
| Auto-updater | Sparkle framework via SPM (`UpdaterController` wrapping `SPUStandardUpdaterController`) |
| Shell execution | Custom `run(_ command: String) -> String` via `/bin/zsh` subprocess |
| Localization | `NSLocalizedString` + `.strings` files per language |
| Persistence | `UserDefaults.standard` (window frame, custom logo path, language) |
| IPC / system data | `system_profiler`, `diskutil`, `nvram`, `sw_vers`, `sysctlbyname`, IOKit, `/bin/zsh` subprocesses |
| Bridging | Objective-C file `ObjCSIP` reads the `csr-active-config` SIP value |

## Repository Layout

```
About-This-Hack-2/
├── Claude.md                          ← this file
├── README.md
├── DOCS/                              ← Developer documentation (markdown)
│   ├── AppKit-XIB-to-SwiftUI.md
│   ├── ATHLogger-to-print.md
│   ├── App-damaged.md
│   ├── Console-warning.md
│   ├── Replace-custom-logo.md
│   └── Transparent-windows.md
├── ImagesTMP/Screenshots/             ← README screenshots (not bundled)
└── About This Hack/                   ← All source code
    ├── AppDelegate.swift              ← App entry point, window/menu setup
    ├── HardwareCollector.swift        ← Central data collector (singleton)
    ├── About This Hack-Bridging-Header.h
    ├── About_This_Hack.entitlements
    ├── Info.plist
    ├── Assets.xcassets/               ← Images (OS badges, disk icons, display icons)
    ├── Bridge/                        ← Objective-C SIP bridge
    │   ├── ObjCSIP.h
    │   └── ObjCSIP.m
    ├── HardwareCollectors/            ← Individual hardware data collectors
    │   ├── HCAudio.swift
    │   ├── HCBootloader.swift
    │   ├── HCCPU.swift
    │   ├── HCDisplay.swift
    │   ├── HCGPU.swift
    │   ├── HCMacModel.swift
    │   ├── HCRAM.swift
    │   ├── HCSerialNumber.swift
    │   ├── HCStartupDisk.swift
    │   └── HCVersion.swift
    ├── Models/                        ← Shared state, data init, utilities
    │   ├── CreateDataFiles.swift      ← Async creation of temp data files
    │   ├── UpdateController.swift     ← Sparkle updater controller wrapper
    │   ├── InitGlobalVariables.swift  ← All global constants and paths
    │   ├── LoadingIndicatorController.swift
    │   ├── SystemFunctions.swift      ← run(), getSysctlValueByKey(), Bundle ext.
    │   ├── Tooltips.swift             ← Lazy tooltip strings (expensive to compute)
    ├── Utilities/                     ← Small helpers
    │   ├── CustomLogoConstants.swift  ← UserDefaults key + Notification.Name
    │   ├── InsertExtension.swift      ← String/Data extensions
    │   ├── Reachability.swift         ← Network reachability helper
    │   └── Shell.swift                ← run() function definition
    ├── Views/                         ← All SwiftUI views + AppState
    │   ├── ContentView.swift          ← Root view: LoadingView or FakeSidebarLayout
    │   ├── ViewController.swift       ← OverviewView + OverviewViewModel
    │   ├── ViewControllerDisplays.swift ← DisplaysView + DisplaysViewModel
    │   ├── ViewControllerStorage.swift  ← StorageView + StorageViewModel
    │   ├── ViewControllerAudio.swift    ← AudioView + AudioViewModel
    │   ├── ViewControllerSupport.swift  ← SupportView
    │   ├── SettingsView.swift           ← Settings window (custom logo)
    │   ├── SettingsWindowController.swift
    │   ├── LanguageSelectorView.swift
    │   ├── LanguageSelectorWindowController.swift
    │   └── WindowController.swift       ← AppState: ObservableObject shared state
    └── {en,es,fr,it}.lproj/
        └── Localizable.strings
```

## Architecture & Data Flow

### Startup sequence

```
AppDelegate.init()
  ├── AppState.shared: registers DataFilesCreated notification observer
  └── CreateDataFiles.getInitDataFilesAsync { }
        └── background thread: runs system_profiler / diskutil commands
              → writes temp files to /private/tmp/.ath/
              → posts DataFilesCreatedNotification

AppState receives DataFilesCreatedNotification
  └── loadDataAsync()
        └── background thread: HardwareCollector.shared.getAllData()
              ├── prefetches temp files into in-memory cache
              ├── runs system_profiler SPDisplaysDataType (no file; stored in cache)
              ├── calls every HC*.shared.getXxx() to pre-warm lazy vars
              └── sets dataHasBeenSet = true
        → main thread: AppState.isDataLoaded = true → ContentView switches to FakeSidebarLayout
```

### Key singletons

| Singleton | Role |
|---|---|
| `AppState.shared` | `ObservableObject` injected via `.environmentObject`. Drives navigation (`selectedSection`), loading state (`isDataLoaded`), sidebar visibility. Also determines `isHackintosh` and `shouldShowAudioTab`. |
| `HardwareCollector.shared` | Central cache. Holds parsed display/storage arrays. `getCachedFileContent(_:)` reads temp files once and caches them. |
| `HCVersion.shared` | OS version string, build number, `MacOSVersion` enum, OS image name. |
| `HCCPU.shared` | CPU brand string and info. |
| `HCRAM.shared` | RAM size string. |
| `HCGPU.shared` | GPU name and info (lazy, reset-able). |
| `HCDisplay.shared` | Primary display summary string (lazy, reset-able). |
| `HCMacModel.shared` | Mac model name + model identifier. |
| `HCSerialNumber.shared` | Serial number + hardware info tooltip. |
| `HCStartupDisk.shared` | Boot volume name + info. |
| `HCBootloader.shared` | Bootloader string (OpenCore/Clover/Apple iBoot/Apple UEFI) + boot-args. Both are `lazy var`. |
| `HCAudio.shared` | Audio codec info (driver, codec, vendor, device, layout). |
| `Tooltips.shared` | Lazy tooltip strings used by OverviewViewModel. |

### Navigation

`AppSection` enum (`.overview`, `.displays`, `.storage`, `.audio`, `.support`) is the navigation token. It lives in `AppState.selectedSection`. `ContentView` (via `FakeSidebarLayout`) switches the detail panel by reading this value. The macOS `Window` menu items call `AppDelegate` actions that write to `AppState.selectedSection` directly.

The sidebar is a plain `HStack` (not `NavigationSplitView`), to avoid tap-event reliability issues on macOS Tahoe.

### View / ViewModel pattern

Each tab's view file contains both the SwiftUI `View` struct and a `ViewModel` struct/class:

- `OverviewView` + `OverviewViewModel: ObservableObject` (class, `@StateObject`)
- `DisplaysView` + `DisplaysViewModel` (enum with static factory)
- `StorageView` + `StorageViewModel` (plain struct)
- `AudioView` + `AudioViewModel` (plain struct)
- `SupportView` (no dedicated VM, links are inline)
- `SettingsView` + `SettingsViewModel: ObservableObject`

### Shell execution

All subprocess calls go through `run(_ command: String) -> String` in `Shell.swift`. It launches `/bin/zsh -c <command>`, reads stdout, and returns the result. **Important:** `waitUntilExit()` is intentionally NOT called (see comment in `Shell.swift`) – calling it would pump the RunLoop and can trigger SwiftUI render-pass assertion crashes. All `run()` calls must happen on background threads.

## Temp Files

Data is collected into `/private/tmp/.ath/` at launch and deleted on termination.

| File path constant | Content |
|---|---|
| `InitGlobVar.hwFilePath` | `system_profiler SPHardwareDataType` |
| `InitGlobVar.sysmemFilePath` | `system_profiler SPMemoryDataType` |
| `InitGlobVar.bootvolnameFilePath` | `diskutil info /` |
| `InitGlobVar.bootvollistFilePath` | `diskutil list /` |
| `InitGlobVar.storagedataFilePath` | `system_profiler SPStorageDataType` |
| `InitGlobVar.scrFilePath` | Virtual key – `system_profiler SPDisplaysDataType` result is stored directly into the `HardwareCollector` cache under this key (never written to disk) |
| `InitGlobVar.oclpXmlFilePath` | `/System/Library/CoreServices/OpenCore-Legacy-Patcher.plist` (system file, read-only) |

## Audio Tab Visibility

The Audio tab is only shown on Hackintoshes with an active audio kext:

1. `AppState.isHackintosh` → true when bootloader is Clover or OpenCore (without OCLP, or with OCLP + AppleALC/VoodooHDA/USB audio).
2. `AppState.shouldShowAudioTab` → true when `isHackintosh` AND `HCAudio` reports driver = `"AppleALC"`, `"VoodooHDA"`, or `"USB"`.
3. The `Audio` menu item in AppDelegate is also validated against `shouldShowAudioTab`.

For VoodooHDA, the `getdump` tool must be installed at `/usr/local/bin/getdump`.

## Localization

- All user-facing strings use `NSLocalizedString("key", comment: "…")`.
- String files live at `{lang}.lproj/Localizable.strings`.
- Supported languages: `en`, `es`, `fr`, `it`.
- Language is changed at runtime by writing `[langCode]` to `UserDefaults "AppleLanguages"` and restarting the app. The Language Selector window (`LanguageSelectorView`) handles this.
- When adding a new string, add it to all four `.strings` files. The key in every file must match exactly.

## Assets

Assets are in `Assets.xcassets`. Notable image sets:

- `Tahoe`, `Sequoia`, `Sonoma`, `Ventura`, `Monterey`, `Big Sur`, etc. – OS badge images used in Overview.
- `{OS} Internal SSD`, `{OS} External SSD`, `{OS} Internal HDD`, `{OS} External HDD` – Storage tab disk icons.
- `MacBook`, `genericLCD`, `LG4K`, `iPad`, `AppleDisplay` – Display tab icons.
- `Audio` – Audio tab icon.
- `AppIcon` – App icon.

## Settings (Custom Logo)

- The Settings window (`⌘,`) lets users drag-drop a 1024×1024 PNG to replace the macOS badge in Overview.
- The path is saved to `UserDefaults` under key `"customLogoPath"` (`CustomLogoConstants.customLogoPathKey`).
- A `Notification.Name.customLogoDidChange` notification is posted when the logo changes; `OverviewViewModel` listens and reloads.

## Sparkle Auto-Updater

- `UpdaterController` wraps `SPUStandardUpdaterController` from the Sparkle framework (SPM dependency, min 2.9.0).
- It publishes `canCheckForUpdates` so `AppDelegate.validateMenuItem` can enable/disable the menu item.
- The "Check for Updates…" menu item (`⌘U`) calls `updaterController?.checkForUpdates()`.

## Building

- Open `About This Hack.xcodeproj` in Xcode 15+.
- Xcode resolves the Sparkle SPM package automatically on first open/build.
- Target: macOS 13.5+, architecture: universal (Apple Silicon + Intel).
- There are no automated test targets in the project.
- The app is storyboard-free: `NSPrincipalClass` points to `AppDelegate`, and `AppDelegate.main()` is the entry point (marked `@main`).

## Common Pitfalls

- **Never call `run()` on the main thread.** It can pump the RunLoop and cause SwiftUI assertion crashes ("setting value during update"). Pre-warm all lazy hardware vars in `HardwareCollector.getAllData()` on a background thread.
- **`HardwareCollector.clearCache()` + `reset()`** must be called if hardware data needs to be refreshed (it resets `HCGPU` and `HCDisplay` lazy vars).
- **`HCBootloader` lazy vars** (`bootloaderInfo`, `bootargsInfo`) are expensive (shell calls). They must be pre-warmed on a background thread inside `getAllData()`.
- **`Tooltips._macModeltoolTip`** runs `system_profiler SPPCIDataType` and must be pre-warmed on a background thread (done in `AppState.loadDataAsync()`).
- **Sidebar toggle animation** uses `withAnimation(.easeInOut(duration: 0.25))`. The sidebar and divider use `.transition(.move(edge: .leading))` / `.transition(.opacity)`.
- **`run()` does not call `waitUntilExit()`** by design (see `Shell.swift` comment). This is intentional and must not be reverted.
- **Transparent window**: the `NSWindow` is set `isOpaque = false`, `backgroundColor = .clear`. All SwiftUI backgrounds use `.ultraThinMaterial` (not opaque colors). There is a commented-out opaque alternative in the source if you need to switch.
- **`AppSection.audio`** is filtered out of the sidebar list when `shouldShowAudioTab` is false.

## Where to Look for Things

| Need to… | Look in |
|---|---|
| Add/change a hardware data field | `HardwareCollectors/HC*.swift` + update the relevant ViewModel in `Views/ViewController*.swift` |
| Add a new tab | Add a case to `AppSection` in `WindowController.swift`, add a new view file in `Views/`, update `FakeSidebarLayout.detailView`, add menu item in `AppDelegate.createMainMenu()` |
| Change global paths or URLs | `Models/InitGlobalVariables.swift` |
| Add/edit a Localized string | All four `{lang}.lproj/Localizable.strings` |
| Change update checker | `Models/UpdateController.swift` (Sparkle `SPUStandardUpdaterController`) |
| Change window appearance | `AppDelegate.createAndShowMainWindow()` |
| Change Settings/custom logo logic | `Views/SettingsView.swift` + `Utilities/CustomLogoConstants.swift` |
| Change tooltip content | `Models/Tooltips.swift` |
| Change sidebar navigation model | `Views/WindowController.swift` (AppState + AppSection) |
| Change how data files are created | `Models/CreateDataFiles.swift` |
| Change how data is read and cached | `HardwareCollector.swift` |
| Understand SIP reading | `Bridge/ObjCSIP.{h,m}` |

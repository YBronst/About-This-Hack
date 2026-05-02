# Releases Changelog

## 4.2.6 (1615) — HDMI audio support

- Add HDMI audio device support to the Audio tab

## 4.2.5 (1613) — USB audio support

- Add USB audio device support to the Audio tab

## 4.2.4 (1610) — Native updater replaces Sparkle

- Sparkle is replaced by a native, lightweight SwiftUI GitHub-based update checker that uses the GitHub versioning API and requires no third-party dependencies
- Localize updater messages

## 4.2.2 (1608) — VoodooHDA audio detection

- Improve audio detection and VoodooHDA support via the `getdump` tool (work in progress)
- Fix accents in the French `Localizable.strings` file
- README: Document audio tab behavior, getdump requirement for VoodooHDA, and update screenshot references
- Assets: Renamed Audio screenshot for AppleALC and added a VoodooHDA screenshot

## 4.2.0 (1604) — Display detection · Audio tab

- Add Audio sidebar tab (work in progress):
  - Displays audio codec information
  - Applies only to Hackintosh having AppleALC enabled
  - Hackintosh using VoodooHDA do not have an audio tab
  - Detection of `alc-layout-id` over `layout-id`
  - Treat OpenCore+OCLP as a Hackintosh (only when audio injection drivers are detected)
- The custom updater system is replaced by Sparkle
- Remove scr.txt intermediary file for SPDisplaysDataType: `system_profiler SPDisplaysDataType` is written to `scr.txt` and then read back into the cache; the file round-trip is unnecessary
- Update Italian translation, thanks to [Anto65](https://github.com/antuneddu)
- Add the refresh rate in the Displays tab
- Add sidebar toggle button to hide / show the sidebar with animation
- Center content when the sidebar is hidden
- Conditionally show scroll indicator in Displays tab: hidden for 1–3 monitors, visible for 4 or more monitors

## 4.0.0 (1595) — Migrate to SwiftUI

- Migrate main UI to SwiftUI keeping app functionality
- Add language menu and language selector window (en, es, fr, it)
- Keep existing Settings window (custom logo) behavior
- Minimum target is macOS 13.5+
- Rework the Displays UI to use a horizontal `ScrollView` and enable full display counts (removed hard limit of 3)
- Replace ATHLogger with print statements (error/warning prints where failures are meaningful for debugging)
- Replace macOS version icons with liquid glass badges, thanks to [chris1111](https://github.com/chris1111)
- The app bundle size has been reduced from 29 to 11 MB

## 3.0.0 (1580) — Faster startup and custom logo

- Shorter app startup time
- Introduces a new Preferences window for customizing the macOS logo in the Overview tab
- Users can drag and drop a 1024×1024 PNG image to set a custom logo, which is persisted in UserDefaults
- Replaces custom updater system by Sparkle
- Adds missing image assets for Tahoe External/Internal HDD and SSD
- UI fixes for macOS Tahoe
- Minimum target is macOS 11.5+

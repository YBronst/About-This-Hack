//
//  WindowController.swift
//  About This Hack
//
//  Shared observable state for the SwiftUI-based main interface.
//

import Foundation
import SwiftUI

// MARK: - Navigation Sections

enum AppSection: String, CaseIterable, Identifiable {
    case overview
    case displays
    case storage
    case audio
    case support

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .overview: return NSLocalizedString("segment.title.overview", comment: "Overview")
        case .displays: return NSLocalizedString("segment.title.displays", comment: "Displays")
        case .storage: return NSLocalizedString("segment.title.storage", comment: "Storage")
        case .audio: return NSLocalizedString("segment.title.audio", comment: "Audio")
        case .support: return NSLocalizedString("segment.title.support", comment: "Support")
        }
    }

    var systemImage: String {
        switch self {
        case .overview: return "info.circle"
        case .displays: return "display"
        case .storage: return "internaldrive"
        case .audio: return "waveform.circle"
        case .support: return "questionmark.circle"
        }
    }

    var tooltip: String {
        switch self {
        case .overview: return NSLocalizedString("segment.tooltip.overview", comment: "Overview tooltip")
        case .displays: return NSLocalizedString("segment.tooltip.displays", comment: "Displays tooltip")
        case .storage: return NSLocalizedString("segment.tooltip.storage", comment: "Storage tooltip")
        case .audio: return NSLocalizedString("segment.tooltip.audio", comment: "Audio tooltip")
        case .support: return NSLocalizedString("segment.tooltip.support", comment: "Support tooltip")
        }
    }
}

// MARK: - App State

/// Shared observable state used by both AppDelegate (menu actions) and ContentView (navigation).
class AppState: ObservableObject {
    nonisolated(unsafe) static let shared = AppState()
    private static let hackintoshAudioDrivers: Set<String> = ["AppleALC", "HDAUniversal", "VoodooHDA", "USB", "HDMI", "DisplayPort"]

    @Published var selectedSection: AppSection? = .overview {
        didSet {
            guard selectedSection != oldValue else { return }
            let tabName = switch selectedSection {
            case .overview: "Overview"
            case .displays: "Displays"
            case .storage: "Storage"
            case .audio: "Audio"
            case .support: "Support"
            case .none: "Unknown"
            }
            print("Switched to tab: \(tabName)")
        }
    }
    @Published var isDataLoaded = false {
        didSet {
            if isDataLoaded && !oldValue {
                print("Hardware data loaded")
            }
        }
    }
    @Published var isSidebarVisible: Bool = true

    /// True when audio codec data is available. Evaluated lazily after data loads.
    /// Returns true during loading so the tab is not prematurely hidden.
    var hasAudioData: Bool {
        guard isDataLoaded else { return true }
        let info = HCAudio.shared.getAudioInfo()
        return !info.vendorName.isEmpty || !info.codecName.isEmpty || !info.layoutId.isEmpty
    }

    nonisolated(unsafe) private static var didPrintRealMac = false
    private static func printRealMacOnce() {
        guard !didPrintRealMac else { return }
        didPrintRealMac = true
        print("Mac: no audio tab")
    }

    /// True when running on a Hackintosh (OpenCore without OCLP, or Clover).
    /// Returns true during loading so the audio tab is not prematurely hidden.
    var isHackintosh: Bool {
        guard isDataLoaded else { return true }
        let bootloader = HCBootloader.shared.getBootloader().trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedBootloader = bootloader.lowercased()

        if normalizedBootloader.hasPrefix("clover") {
            return true
        }
        if normalizedBootloader.hasPrefix("opencore") {
            if FileManager.default.fileExists(atPath: InitGlobVar.oclpXmlFilePath) {
                let driver = HCAudio.shared.getAudioInfo().driver
                // OpenCore + OCLP can mean either a real Mac patched for newer macOS
                // compatibility, or a Hackintosh that uses OCLP for driver patches
                // (e.g. audio, WiFi on Sonoma).  Treat as Hackintosh when
                // AppleALC, HDAUniversal, VoodooHDA, USB, HDMI, or DisplayPort audio is detected as the default output.
                return AppState.hackintoshAudioDrivers.contains(driver)
            }
            return true
        }

        // Fallback for OpenCore systems where bootloader string lookup failed:
        // Known Hackintosh audio drivers (AppleALC / HDAUniversal / VoodooHDA /
        // USB / HDMI / DisplayPort) indicate this is not a stock Apple boot path.
        let driver = HCAudio.shared.getAudioInfo().driver
        if AppState.hackintoshAudioDrivers.contains(driver) {
            return true
        }

        // Apple iBoot (Apple Silicon) or Apple UEFI → real Mac
        if normalizedBootloader.hasPrefix("apple iboot") || normalizedBootloader.hasPrefix("apple uefi") {
            AppState.printRealMacOnce()
        }
        return false
    }

    /// True when the audio tab should be visible.
    /// Shown on Hackintoshes running AppleALC, HDAUniversal, VoodooHDA (with getdump available),
    /// or with a USB, HDMI, or DisplayPort audio device set as the default output.
    /// Hidden on real Macs and on Hackintoshes where none of these are active
    /// (or when VoodooHDA is active but getdump is not installed).
    /// Returns true during loading so the tab is not prematurely hidden.
    var shouldShowAudioTab: Bool {
        guard isDataLoaded else { return true }
        guard isHackintosh else { return false }
        let driver = HCAudio.shared.getAudioInfo().driver
        return AppState.hackintoshAudioDrivers.contains(driver)
    }

    private let defaults = UserDefaults.standard
    private let windowFrameKey = "MainWindowFrame"
    private var dataFilesToken: NSObjectProtocol?

    private init() {
        // Use block-based observer to avoid @objc on a non-NSObject class.
        dataFilesToken = NotificationCenter.default.addObserver(
            forName: CreateDataFiles.dataFilesCreatedNotification,
            object: nil,
            queue: nil
        ) { _ in
            AppState.shared.loadDataAsync()
        }
        // Data files might already be ready if the app was restarted.
        if CreateDataFiles.dataFilesCreated {
            loadDataAsync()
        }
    }

    private func loadDataAsync() {
        DispatchQueue.global(qos: .userInitiated).async {
            HardwareCollector.shared.getAllData()
            // Pre-warm Tooltips._macModeltoolTip on the background thread.
            // It runs `system_profiler SPPCIDataType` via run(), which would
            // otherwise execute on the main thread when OverviewViewModel.init()
            // accesses macModeltoolTip during a SwiftUI body-evaluation pass,
            // causing run() → task.waitUntilExit() to pump the run loop and
            // trigger a "setting value during update" AttributeGraph assertion.
            _ = Tooltips.shared.macModeltoolTip
            DispatchQueue.main.async {
                AppState.shared.isDataLoaded = true
            }
        }
    }

    // MARK: - Window Frame Persistence

    func savedWindowFrame(for size: NSSize) -> NSRect? {
        guard let saved = defaults.string(forKey: windowFrameKey) else { return nil }
        var frame = NSRectFromString(saved)
        frame.size = size
        return frame
    }

    func saveWindowFrame(_ frame: NSRect) {
        defaults.set(NSStringFromRect(frame), forKey: windowFrameKey)
    }

    deinit {
        if let token = dataFilesToken {
            NotificationCenter.default.removeObserver(token)
        }
    }
}

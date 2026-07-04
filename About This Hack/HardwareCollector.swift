//
//  HardwareCollector.swift
//  HardwareCollector
//

import AppKit
import Foundation

class HardwareCollector {
    static let shared = HardwareCollector()
    private init() {}

    // File content cache
    private var fileContentCache: [String: String] = [:]
    private let cacheLock = NSLock()

    // Thread-safe flag for getAllData()
    private var _dataHasBeenSet = false
    private let dataInitLock = NSLock()
    var dataHasBeenSet: Bool {
        get {
            dataInitLock.lock()
            defer { dataInitLock.unlock() }
            return _dataHasBeenSet
        }
        set {
            dataInitLock.lock()
            defer { dataInitLock.unlock() }
            _dataHasBeenSet = newValue
        }
    }

    var numberOfDisplays = NSScreen.screens.count
    var displayRes: [String] = []
    var displayRefreshRates: [String] = []
    var displayNames: [String] = []
    var storageType = false
    var storageData = ""
    var storagePercent = 0.0
    var deviceLocation = ""
    var deviceProtocol = ""
    var hasBuiltInDisplay = false

    func getCachedFileContent(_ path: String) -> String? {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        if let cached = fileContentCache[path] {
            return cached
        }

        guard let content = try? String(contentsOfFile: path, encoding: .utf8), !content.isEmpty else {
            return nil
        }

        fileContentCache[path] = content
        return content
    }

    /// Store content directly into the file cache under the given path key.
    /// Used as a fallback to populate the cache from a freshly-run command
    /// when the corresponding on-disk file was not written in time.
    func storeCachedFileContent(_ path: String, content: String) {
        guard !content.isEmpty else { return }
        cacheLock.lock()
        defer { cacheLock.unlock() }
        fileContentCache[path] = content
    }

    func clearCache() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        fileContentCache.removeAll()

        // Reset lazy properties in hardware collectors
        HCGPU.shared.reset()
        HCDisplay.shared.reset()
    }

    func getAllData() {
        guard !dataHasBeenSet else { return }

        // Clear cache to ensure we read fresh data files
        clearCache()

        // Prefetch commonly used files first
        let commonFiles = [
            InitGlobVar.hwFilePath,
            InitGlobVar.bootvolnameFilePath,
            InitGlobVar.storagedataFilePath,
            InitGlobVar.sysmemFilePath,
            InitGlobVar.bootvollistFilePath,
            InitGlobVar.oclpXmlFilePath,
        ]

        for path in commonFiles {
            _ = getCachedFileContent(path)
        }

        // Run system_profiler SPDisplaysDataType directly (no intermediate file) and
        // populate the cache so that all GPU/display lookups via getCachedFileContent
        // find the data without touching the file system.
        let scrContent = run("system_profiler SPDisplaysDataType")
        if !scrContent.isEmpty {
            storeCachedFileContent(InitGlobVar.scrFilePath, content: scrContent)
        }

        // Initialize all hardware collectors in a specific order
        HCVersion.shared.getVersion()
        HCMacModel.shared.getMacModel()
        _ = HCCPU.shared.getCPU()
        _ = HCRAM.shared.getRam()
        _ = HCStartupDisk.shared.getStartupDisk()
        _ = HCDisplay.shared.getDisp()
        _ = HCGPU.shared.getGPU()

        // Initialize display and storage info
        hasBuiltInDisplay = checkForBuiltInDisplay()
        displayRes = getDisplayRes()
        displayRefreshRates = getDisplayRefreshRates()
        displayNames = getDisplayNames()
        (storageType, storageData, storagePercent) = getStorageInfo()

        // Pre-warm HCBootloader lazy vars here on the background thread so that
        // their internal run() calls never execute on the main thread.  Without
        // this pre-warming, the lazy vars are initialized on first access inside
        // OverviewViewModel.init(), which is invoked during a SwiftUI body-
        // evaluation pass on the main thread.  run() calls task.waitUntilExit(),
        // which pumps the run loop, allowing a pending task(id:) continuation to
        // write @State while SwiftUI is still in its render pass, triggering
        // "precondition failure: setting value during update: 536" → SIGABRT.
        _ = HCBootloader.shared.getBootloader()
        _ = HCBootloader.shared.getBootargs()

        // Pre-warm HCAudio on the background thread for the same reasons.
        _ = HCAudio.shared.getAudioInfo()

        dataHasBeenSet = true
    }

    /// Extracts the pixel-dimensions portion from a resolution field value string,
    /// stripping any trailing "(…)" parenthesised annotations and "@ XX Hz" refresh-rate suffix.
    private func extractDimensions(from fieldValue: String) -> String {
        var value = fieldValue
            .components(separatedBy: "(").first?
            .trimmingCharacters(in: .whitespaces) ?? ""
        if let atRange = value.range(of: #"\s*@\s*[\d.]+ ?Hz"#, options: .regularExpression) {
            value = String(value[..<atRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        return value
    }

    private func getDisplayRes() -> [String] {
        guard let content = getCachedFileContent(InitGlobVar.scrFilePath) else { return [] }
        let lines = content.components(separatedBy: .newlines)
        var result: [String] = []

        for (i, line) in lines.enumerated() {
            guard line.contains("Resolution:"),
                  let resRange = line.range(of: "Resolution:") else { continue }

            // Extract the Resolution value as fallback
            let resValue = extractDimensions(from: String(line[resRange.upperBound...]))

            // Look ahead for "UI Looks like:" within the same display block.
            // If found, use its dimensions as the effective (scaled) resolution.
            var scaledResolution: String? = nil
            for j in (i + 1) ..< min(i + 6, lines.count) {
                let next = lines[j]
                // Another Resolution: line means a new display — stop looking
                if next.contains("Resolution:") { break }
                if next.contains("UI Looks like:"),
                   let uiRange = next.range(of: "UI Looks like:")
                {
                    let uiValue = extractDimensions(from: String(next[uiRange.upperBound...]))
                    if !uiValue.isEmpty {
                        scaledResolution = uiValue
                    }
                    break
                }
            }

            let finalRes = scaledResolution ?? resValue
            if !finalRes.isEmpty {
                result.append(finalRes)
            }
        }
        return result
    }

    private func getDisplayRefreshRates() -> [String] {
        guard let content = getCachedFileContent(InitGlobVar.scrFilePath) else { return [] }
        let lines = content.components(separatedBy: .newlines)
        var result: [String] = []

        for (i, line) in lines.enumerated() {
            guard line.contains("Resolution:"),
                  let resRange = line.range(of: "Resolution:") else { continue }

            let resValue = String(line[resRange.upperBound...]).trimmingCharacters(in: .whitespaces)

            // First try the Resolution line itself (e.g. "2560 x 1440 @ 60 Hz")
            if let match = resValue.range(of: #"@\s*[\d.]+ ?Hz"#, options: .regularExpression) {
                result.append(String(resValue[match])
                    .replacingOccurrences(of: "@", with: "")
                    .trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: #"(\d)Hz"#, with: "$1 Hz", options: .regularExpression))
                continue
            }

            // Fallback: look for "UI Looks like:" within the next few lines of the
            // same display block (Retina / HiDPI displays report Hz there, not on
            // the Resolution line).  Stop early if we reach another display property
            // that signals we have moved past the relevant block.
            var rate = ""
            for j in (i + 1) ..< min(i + 6, lines.count) {
                let next = lines[j]
                let nextTrimmed = next.trimmingCharacters(in: .whitespaces)
                // Another Resolution: line means a new display — stop looking
                if next.contains("Resolution:") { break }
                if next.contains("UI Looks like:"),
                   let uiRange = next.range(of: "UI Looks like:")
                {
                    let uiValue = String(next[uiRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                    if let match = uiValue.range(of: #"@\s*[\d.]+ ?Hz"#, options: .regularExpression) {
                        rate = String(uiValue[match])
                            .replacingOccurrences(of: "@", with: "")
                            .trimmingCharacters(in: .whitespaces)
                            .replacingOccurrences(of: #"(\d)Hz"#, with: "$1 Hz", options: .regularExpression)
                    }
                    break
                }
                // A display-name line (ends with ":" and has no spaces in the trimmed form, or
                // is just a section header) means we left the current display block — stop.
                if !nextTrimmed.isEmpty, nextTrimmed.hasSuffix(":"), !nextTrimmed.contains(" ") {
                    break
                }
            }
            result.append(rate)
        }
        return result
    }

    private func getDisplayNames() -> [String] {
        guard let content = getCachedFileContent(InitGlobVar.scrFilePath) else { return [] }

        var displayNames: [String] = []
        var inDisplaysSection = false

        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed == "Displays:" {
                inDisplaysSection = true
                continue
            }

            // A non-empty line at shallower indentation (< 8 spaces) means we have
            // left the current Displays: block (e.g., another GPU section header).
            // Reset so we don't capture GPU names as display names.
            if inDisplaysSection, !trimmed.isEmpty,
               !line.hasPrefix("        "), !line.hasPrefix("\t")
            {
                inDisplaysSection = false
            }

            if inDisplaysSection, trimmed.hasSuffix(":") {
                // This is a display name (e.g., "G27Q:")
                let name = String(trimmed.dropLast())
                displayNames.append(name)
            }
        }

        return displayNames
    }

    private func checkForBuiltInDisplay() -> Bool {
        guard let content = getCachedFileContent(InitGlobVar.scrFilePath) else { return false }
        let lower = content.lowercased()
        return lower.contains("connection type: internal") || lower.contains("display type: built-in")
    }

    private func getStorageInfo() -> (Bool, String, Double) {
        guard let content = getCachedFileContent(InitGlobVar.bootvolnameFilePath) else {
            return (false, "Error reading file", 0)
        }

        let lines = content.components(separatedBy: .newlines)
        deviceProtocol = lines.first { $0.contains("Protocol:") }?.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: " fabric$", with: "", options: [.regularExpression, .caseInsensitive]) ?? "Unknown"
        deviceLocation = lines.first { $0.contains("Device Location:") }?.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? "Unknown"

        let isSSd = content.contains("Solid State: Yes")
        let (sizeGB, availableGB) = parseStorageSize(lines)
        let percent = availableGB / sizeGB
        let percentFree = String(format: "%.2f", percent * 100)

        let storageInfo = """
        \(HCStartupDisk.shared.getStartupDisk()) (\(deviceLocation) \(deviceProtocol))
        \(String(format: "%.2f", sizeGB)) GB (\(String(format: "%.2f", availableGB)) GB \(NSLocalizedString("storage.available", comment: "Available storage label")) - \(percentFree)%)
        """

        return (isSSd, storageInfo, 1 - percent)
    }

    private func parseStorageSize(_ lines: [String]) -> (Double, Double) {
        let sizeLine = lines.first { $0.contains("Total Space:") }?.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? "0 B"
        let availableLine = lines.first { $0.contains("Free Space:") }?.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? "0 B"

        let (size, sizeUnit) = parseSize(sizeLine)
        let (available, availableUnit) = parseSize(availableLine)

        return (convertToGB(size, unit: sizeUnit), convertToGB(available, unit: availableUnit))
    }

    private func parseSize(_ sizeString: String) -> (Double, String) {
        let components = sizeString.components(separatedBy: .whitespaces)
        guard components.count >= 2, let size = Double(components[0]) else { return (0, "B") }
        return (size, components[1])
    }

    private func convertToGB(_ size: Double, unit: String) -> Double {
        switch unit.uppercased() {
        case "B": return size / 1_000_000_000
        case "KB": return size / 1_000_000
        case "MB": return size / 1000
        case "GB": return size
        case "TB": return size * 1000
        default: return size
        }
    }
}
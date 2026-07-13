//
//  HCDisplay.swift
//  About This Hack
//

import Foundation

class HCDisplay {
    static let shared = HCDisplay()
    private init() {}

    private var _displayInfo: (mainDisplay: String, allDisplays: String)?
    private let displayLock = NSLock()

    private var displayInfo: (mainDisplay: String, allDisplays: String) {
        displayLock.lock()
        defer { displayLock.unlock() }

        if let cached = _displayInfo {
            return cached
        }

        let computed = computeDisplayInfo()
        _displayInfo = computed
        return computed
    }

    func reset() {
        displayLock.lock()
        defer { displayLock.unlock() }
        _displayInfo = nil
    }

    private func computeDisplayInfo() -> (mainDisplay: String, allDisplays: String) {
        // Use cached data from HardwareCollector instead of file I/O
        guard let content = HardwareCollector.shared.getCachedFileContent(InitGlobVar.scrFilePath) else {
            print("Error: No display data available from HardwareCollector")
            return ("Unknown Display", "No display information available")
        }

        let lines = content.components(separatedBy: .newlines)

        // Find the Displays: subsection anywhere in the output
        guard let displaysIndex = lines.firstIndex(where: { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed == "Displays:"
        }) else {
            print("Error: Displays section not found in cached data")
            return ("Unknown Display", "No display information available")
        }

        // Collect display lines - they are indented after "Displays:"
        // Skip blank lines (modern system_profiler output has blank lines between sections).
        // Stop only when a non-empty line returns to a shallower indentation level.
        var displayLines: [String] = []
        var i = displaysIndex + 1
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                i += 1
                continue
            }

            // Stop when indentation decreases to root level (no longer inside Displays:)
            if !line.hasPrefix("        "), !line.hasPrefix("\t") {
                break
            }

            displayLines.append(line)
            i += 1
        }

        let mainDisplay = getMainDisplayInfo(from: displayLines)
        // For a full list, include the same block
        let allDisplays = getAllDisplaysInfo(from: displayLines)

        return (mainDisplay, allDisplays)
    }

    func getDisp() -> String {
        return displayInfo.mainDisplay
    }

    func getDispInfo() -> String {
        return displayInfo.allDisplays
    }

    private func cleanLine(_ line: String) -> String {
        line.trimmingCharacters(in: .whitespaces)
    }

    private func extractDimensions(from fieldValue: String) -> String {
        var value = fieldValue
            .components(separatedBy: "(").first?
            .trimmingCharacters(in: .whitespaces) ?? ""
        if let atRange = value.range(of: #"\s*@\s*[\d.]+ ?Hz"#, options: .regularExpression) {
            value = String(value[..<atRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        return value
    }

    private func getMainDisplayInfo(from lines: [String]) -> String {
        var displayName = "Unknown Display"
        var resolution = "Unknown Resolution"

        guard let firstDisplayIndex = lines.firstIndex(where: { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.hasSuffix(":") && !trimmed.contains(": ")
        }) else {
            return "\(displayName) (\(resolution))"
        }

        displayName = String(lines[firstDisplayIndex].trimmingCharacters(in: .whitespaces).dropLast())

        for i in (firstDisplayIndex + 1) ..< lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if trimmed.hasSuffix(":"), !trimmed.contains("Resolution:") {
                break
            }
            if trimmed.contains("Resolution:"), let resRange = trimmed.range(of: "Resolution:") {
                let resValue = extractDimensions(from: String(trimmed[resRange.upperBound...]))
                var scaledResolution: String?
                let maxResolutionLookAhead = 6 // The "UI Looks like:" field is expected within 6 lines after "Resolution:" in the same display block.
                for lookAheadIndex in (i + 1) ..< min(i + maxResolutionLookAhead, lines.count) {
                    let nextTrimmed = lines[lookAheadIndex].trimmingCharacters(in: .whitespaces)
                    if (nextTrimmed.contains("Resolution:") || nextTrimmed.hasSuffix(":")),
                       !nextTrimmed.contains("UI Looks like:")
                    {
                        break
                    }
                    if nextTrimmed.contains("UI Looks like:"),
                       let uiRange = nextTrimmed.range(of: "UI Looks like:")
                    {
                        let uiValue = extractDimensions(from: String(nextTrimmed[uiRange.upperBound...]))
                        if !uiValue.isEmpty {
                            scaledResolution = uiValue
                        }
                        break
                    }
                }
                let finalResolution = scaledResolution ?? resValue
                if !finalResolution.isEmpty {
                    resolution = finalResolution
                }
                break
            }
        }

        return "\(displayName) (\(resolution))"
    }

    private func getAllDisplaysInfo(from lines: [String]) -> String {
        var result = ""
        var currentSection = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasSuffix(":") {
                if !currentSection.isEmpty {
                    result += currentSection + "\n"
                }
                currentSection = "\n" + line
            } else if !trimmed.isEmpty {
                currentSection += "\n" + line
            }
        }

        if !currentSection.isEmpty {
            result += currentSection
        }

        return result.trimmingCharacters(in: .newlines)
    }
}

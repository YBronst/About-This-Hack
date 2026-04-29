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

    private func getMainDisplayInfo(from lines: [String]) -> String {
        var displayName = "Unknown Display"
        var resolution = "Unknown Resolution"
        var foundFirstDisplay = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Display names are indented and end with ":"
            if trimmed.hasSuffix(":") && !foundFirstDisplay {
                displayName = String(trimmed.dropLast())
                foundFirstDisplay = true
            } else if foundFirstDisplay && trimmed.contains("Resolution:") {
                resolution = trimmed.components(separatedBy: "Resolution:").last?
                    .components(separatedBy: "(").first?
                    .trimmingCharacters(in: .whitespaces) ?? resolution
                break // We have the first display's info
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

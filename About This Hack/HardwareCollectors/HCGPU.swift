import Foundation

class HCGPU {
    static let shared = HCGPU()
    private init() {}

    private var _gpuInfo: String?
    private let gpuLock = NSLock()

    private var gpuInfo: String {
        gpuLock.lock()
        defer { gpuLock.unlock() }

        if let cached = _gpuInfo {
            return cached
        }

        let computed = computeGPUInfo()
        _gpuInfo = computed
        return computed
    }

    func reset() {
        gpuLock.lock()
        defer { gpuLock.unlock() }
        _gpuInfo = nil
    }

    private func computeGPUInfo() -> String {
        // Use cached data from HardwareCollector instead of file I/O
        guard let content = HardwareCollector.shared.getCachedFileContent(InitGlobVar.scrFilePath) else {
            print("Error: No GPU data available from HardwareCollector")
            return ""
        }

        let lines = content.components(separatedBy: .newlines)
        var chipset = "", vram = "", metal = ""
        // Fallback: the GPU section header line (e.g., "    AMD Radeon RX 580:")
        var gpuSectionHeader = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Capture the first GPU section header (4-space indent, ends with ":")
            // as a fallback name in case "Chipset Model:" is absent.
            if gpuSectionHeader.isEmpty,
               line.hasPrefix("    "), !line.hasPrefix("     "),
               trimmed.hasSuffix(":"), trimmed.count > 1
            {
                let headerName = String(trimmed.dropLast())
                    .replacingOccurrences(of: "Intel ", with: "")
                    .replacingOccurrences(of: "NVIDIA ", with: "")
                    .replacingOccurrences(of: "AMD ", with: "")
                    .trimmingCharacters(in: .whitespaces)
                if !headerName.isEmpty {
                    gpuSectionHeader = headerName
                }
            }

            if chipset.isEmpty, trimmed.hasPrefix("Chipset Model:") {
                let value = trimmed.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
                if !value.isEmpty {
                    chipset = value.replacingOccurrences(of: "Intel ", with: "")
                        .replacingOccurrences(of: "NVIDIA ", with: "")
                        .replacingOccurrences(of: "AMD ", with: "")
                }
            } else if vram.isEmpty, trimmed.hasPrefix("VRAM") {
                let value = trimmed.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
                if !value.isEmpty {
                    vram = value
                }
            } else if metal.isEmpty, trimmed.hasPrefix("Metal Support:") {
                let value = trimmed.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
                if !value.isEmpty {
                    metal = value
                }
            }

            // Stop when we hit the Displays section
            if trimmed == "Displays:" {
                break
            }
        }

        // If "Chipset Model:" was not found, fall back to the GPU section header.
        if chipset.isEmpty {
            chipset = gpuSectionHeader
        }

        // Build result based on what we found
        var result = chipset
        if !vram.isEmpty {
            result += " \(vram)"
        }
        if !metal.isEmpty {
            result += " (\(metal))"
        }

        return result.trimmingCharacters(in: .whitespaces)
    }

    func getGPU() -> String {
        return gpuInfo
    }

    func getGPUInfo() -> String {
        // Use cached data from HardwareCollector
        guard let content = HardwareCollector.shared.getCachedFileContent(InitGlobVar.scrFilePath) else {
            print("Error: No GPU details available from HardwareCollector")
            return "Graphics\n"
        }

        let filteredLines = content.components(separatedBy: .newlines)
            .filter { !$0.contains("Graphics/Displays:") &&
                !$0.hasPrefix("      Displays:") &&
                !$0.hasPrefix("        ") &&
                !$0.hasPrefix("          ")
            }
            .map { line in
                line.trimmingCharacters(in: .whitespaces)
                    .components(separatedBy: .whitespaces)
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
            }

        return "Graphics\n" + filteredLines.joined(separator: "\n")
    }
}

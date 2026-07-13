//
//  HCCPU.swift
//  About This Hack
//

import Foundation

class HCCPU {
    static let shared = HCCPU()
    private init() {}

    private lazy var cpuInfo: (brand: String, details: String, coreCount: Int, isAppleSilicon: Bool) = {
        let brand = getSysctlValueByKey(inputKey: "machdep.cpu.brand_string")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown CPU"
        let isAppleSilicon = brand.hasPrefix("Apple")
        let coreCount = isAppleSilicon ? getAppleSiliconCoreCount() : getCPUCoreCount()
        let details = getCPUDetails(isAppleSilicon: isAppleSilicon, coreCount: coreCount)
        return (brand, details, coreCount, isAppleSilicon)
    }()

    func getCPU() -> String {
        // Use cached core count from cpuInfo instead of calling getCPUCoreCount() again
        let cpuCoreCount = cpuInfo.coreCount
        let modifiedBrand = cpuInfo.brand.replacingOccurrences(of: "(R)", with: "").replacingOccurrences(of: "(TM)", with: "")
        let hasValidCoreCount = cpuCoreCount > 0

        if cpuInfo.isAppleSilicon, hasValidCoreCount {
            return "\(modifiedBrand) (\(cpuCoreCount) cores)"
        }

        if cpuCoreCount >= 2 {
            return "\(cpuCoreCount)x \(modifiedBrand)"
        } else {
            return modifiedBrand
        }
    }

    func getCPUInfo() -> String {
        return cpuInfo.details
    }

    func getCPUCoreCount() -> Int {
        var count: UInt32 = 0
        var size = MemoryLayout<UInt32>.size
        let result = sysctlbyname("hw.packages", &count, &size, nil, 0)

        if result == 0 {
            return Int(count)
        } else {
            print("Warning: Failed to get physical CPU count via hw.packages: \(String(cString: strerror(errno)))")
            // Fallback or alternative method can be added here if needed
            // For now, let's try hw.physicalcpu
            var physicalCPU: UInt32 = 0
            var sizePhysical = MemoryLayout<UInt32>.size
            if sysctlbyname("hw.physicalcpu", &physicalCPU, &sizePhysical, nil, 0) == 0 {
                return Int(physicalCPU)
            } else {
                print("Warning: Failed to get physical CPU count via hw.physicalcpu: \(String(cString: strerror(errno)))")
            }
            // And hw.logicalcpu as another fallback
            var logicalCPU: UInt32 = 0
            var sizeLogical = MemoryLayout<UInt32>.size
            if sysctlbyname("hw.logicalcpu", &logicalCPU, &sizeLogical, nil, 0) == 0 {
                return Int(logicalCPU)
            } else {
                print("Error: Failed to get any CPU count: \(String(cString: strerror(errno)))")
            }
            return -1
        }
    }

    private func getAppleSiliconCoreCount() -> Int {
        var count: UInt32 = 0
        var size = MemoryLayout<UInt32>.size
        if sysctlbyname("machdep.cpu.core_count", &count, &size, nil, 0) == 0 {
            return Int(count)
        }
        return getCPUCoreCount()
    }

    private func getCPUDetails(isAppleSilicon: Bool, coreCount: Int) -> String {
        if isAppleSilicon {
            return coreCount > 0 ? String(format: NSLocalizedString("cpu.total_cores", comment: ""), coreCount) : NSLocalizedString("cpu.total_cores_unknown", comment: "")
        }

        guard let content = HardwareCollector.shared.getCachedFileContent(InitGlobVar.hwFilePath) else {
            print("Error: Unable to read CPU details from \(InitGlobVar.hwFilePath)")
            return "Unable to read CPU details"
        }

        return content.components(separatedBy: .newlines)
            .drop { !$0.contains("Processor Name:") }
            .prefix { !$0.contains("Memory:") }
            .joined(separator: "\n")
    }
}

//
//  SystemFunctions.swift
//  About This Hack
//

import AppKit
import Cocoa
import Darwin

nonisolated(unsafe) var thisApplicationVersion = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String

/// Define RTLD_DEFAULT for symbol lookup
nonisolated(unsafe) let RTLD_DEFAULT = UnsafeMutableRawPointer(bitPattern: -2)

func initPortDefault() -> mach_port_t {
    if #available(macOS 12.0, *) {
        guard let sym = dlsym(RTLD_DEFAULT, "kIOMainPortDefault") else {
            return kIOMainPortDefault
        }
        let ptr = sym.assumingMemoryBound(to: mach_port_t.self)
        return ptr.pointee
    } else {
        return kIOMasterPortDefault
    }
}

func getSysctlValueByKey(inputKey sysctlKey: String) -> String? {
    var oNbrBytes = 0
    sysctlbyname(sysctlKey, nil, &oNbrBytes, nil, 0)
    var sysctlValue = [CChar](repeating: 0, count: Int(oNbrBytes))
    sysctlbyname(sysctlKey, &sysctlValue, &oNbrBytes, nil, 0)
    let trimmed = sysctlValue.prefix(while: { $0 != 0 }).map(UInt8.init)
    return String(validating: trimmed, as: UTF8.self) ?? "unknown"
}

extension Bundle {
    /// Application name shown under the application icon.
    var applicationName: String? {
        object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
            object(forInfoDictionaryKey: "CFBundleName") as? String ??
            object(forInfoDictionaryKey: "CFBundleExecutable") as? String
    }
}

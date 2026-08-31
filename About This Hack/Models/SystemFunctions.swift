//
//  SystemFunctions.swift
//  About This Hack
//
// Update by YBronst https://github.com/YBronst
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

import Foundation

func getSysctlValueByKey(inputKey sysctlKey: String) -> String? {
    var oNbrBytes = 0
    // 1. Getting the buffer size
    sysctlbyname(sysctlKey, nil, &oNbrBytes, nil, 0)
    
    // Protection in case the key is not found
    guard oNbrBytes > 0 else { return nil }
    
    // 2. Allocate a buffer for the C-string
    var sysctlValue = [CChar](repeating: 0, count: oNbrBytes)
    sysctlbyname(sysctlKey, &sysctlValue, &oNbrBytes, nil, 0)
    
    // 3. We trim off the null terminator and decode via an explicit Array(CUnsignedChar)
    let cleanBytes = sysctlValue.prefix(while: { $0 != 0 })
    return String(decoding: cleanBytes.map(UInt8.init), as: UTF8.self)
}

extension Bundle {
    /// Application name shown under the application icon.
    var applicationName: String? {
        object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
            object(forInfoDictionaryKey: "CFBundleName") as? String ??
            object(forInfoDictionaryKey: "CFBundleExecutable") as? String
    }
}

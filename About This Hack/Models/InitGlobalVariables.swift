//
//  InitGlobalVariables.swift
//

import AppKit
import Foundation

class InitGlobVar {
    // Computed property for thisApplicationName
    static var thisApplicationName: String {
        (Bundle.main.applicationName ?? "").replacingOccurrences(of: ".app", with: "")
    }

    static var athfilesDirectory = "/.ath"
    static var tempDirectory = "/private/tmp"

    // Calculated property for athDirectory
    static var athDirectory: String {
        tempDirectory + athfilesDirectory
    }

    static let defaultfileManager = FileManager.default

    // OCLP Dict File (if exists) where Patch Version Commit and DateTime will be extracted
    static var oclpXmlFilePath = "/System/Library/CoreServices/OpenCore-Legacy-Patcher.plist"
    static var bdmesgExecID = "/usr/local/bin/bdmesg"

    // ioreg Dir perl script and pci ids and names files
    static var whichLocation = "/usr/bin/which"
    static var curlLocation: String = run(whichLocation + " curl  | /usr/bin/tr -d '\n'")

    // Files with Overview, Displays and Storage detailed Datas
    static var hwFilePath = athDirectory + "/hw.txt"
    static var scrFilePath = athDirectory + "/scr.txt"
    static var scrXmlFilePath = athDirectory + "/scrXml.txt"
    static var bootvollistFilePath = athDirectory + "/sysbootvollist.txt"
    static var sysmemFilePath = athDirectory + "/sysmem.txt"
    static var syssoftdataFilePath = athDirectory + "/syssoftdata.txt"
    static var bootvolnameFilePath = athDirectory + "/sysvolname.txt"
    static var storagedataFilePath = athDirectory + "/storagedata.txt"

    // Used by ViewController
    static var systemReportSP = "/System/Library/SystemProfiler/SPPlatformReporter.spreporter"
    static var softwareUpdateSP = "/System/Library/PreferencePanes/SoftwareUpdate.prefPane"
    static var softwareUpdateURL = "x-apple.systempreferences:com.apple.Software-Update-Settings.extension"

    // Used by ViewControllerDisplays
    static var displayPrefPane = "/System/Library/PreferencePanes/Displays.prefPane"

    // Used by ViewControllerSupport
    static var macOSUserGuideURL = "https://support.apple.com/guide/mac-help/welcome/mac"
    static var whatsNewInMacOSURL = "https://www.apple.com/macos/ventura/"
    static var AppleSupportURL = "https://support.apple.com"
    static var HackintoshInstallURL = "https://dortania.github.io/OpenCore-Install-Guide/troubleshooting/troubleshooting.html#table-of-contents"
    static var MacBasicsURL = "https://help.apple.com/macos/big-sur/mac-basics/"
    static var MacUserGuideURL = "https://support.apple.com/manuals"

    static var nvramOpencoreVersion = "4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:opencore-version"
}

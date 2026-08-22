//
//  ViewControllerDisplays.swift
//  About This Hack
//
//  SwiftUI Displays tab: shows connected displays with icons, names, resolutions and display connection type
//

import AppKit
import SwiftUI

// MARK: - Displays View

struct DisplaysView: View {
    private let displays: [DisplayInfo] = DisplaysViewModel.buildDisplayList()

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            displayRow
                .padding(.bottom, 12)
           // Divider()
            HStack {
                Spacer()
                Button(NSLocalizedString("displays.preferences", comment: "Display Preferences button")) {
                    openDisplayPreferences()
                }
                Spacer()
            }
            .padding(.top, 14)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Displays Row

    @ViewBuilder
    private var displayRow: some View {
        if displays.isEmpty {
            Text(NSLocalizedString("displays.none", comment: "No displays found"))
                .foregroundColor(.secondary)
        } else {
            GeometryReader { geometry in
                if displays.count >= 2 {
                    HorizontalScrollViewRepresentable(minWidth: geometry.size.width) {
                        HStack(alignment: .top, spacing: 32) {
                            ForEach(displays) { info in
                                DisplayCard(info: info)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 38)
                        .frame(minWidth: geometry.size.width, alignment: .center)
                    }
                } else {
                    ScrollView(.horizontal) {
                        HStack(alignment: .top, spacing: 32) {
                            ForEach(displays) { info in
                                DisplayCard(info: info)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 38)
                        .frame(minWidth: geometry.size.width, alignment: .center)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .frame(height: 310)
        }
    }

    private func openDisplayPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.displays") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Horizontal Scroll View (NSScrollView wrapper for always-visible scrollbar)

private struct HorizontalScrollViewRepresentable<Content: View>: NSViewRepresentable {
    let minWidth: CGFloat
    @ViewBuilder let content: () -> Content

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.scrollerStyle = .legacy
        scrollView.drawsBackground = false // Glass effect
        scrollView.borderType = .noBorder // Glass effect

        let hostingView = NSHostingView(rootView: AnyView(content()))
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.documentView = hostingView

        NSLayoutConstraint.activate([
            hostingView.heightAnchor.constraint(equalTo: scrollView.contentView.heightAnchor)
        ])

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let hostingView = nsView.documentView as? NSHostingView<AnyView> {
            hostingView.rootView = AnyView(content())
        }
    }
}

// MARK: - Display Card

private struct DisplayCard: View {
    let info: DisplayInfo

    var body: some View {
        VStack(spacing: 8) {
            Image(nsImage: info.image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 200)
            
            Text(info.name)
                .font(.system(size: 13, weight: .medium))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: 120)
            
            // Displaying the connection type from an Enum
            Text(info.connectionType.description)
                .font(.system(size: 10))
                .foregroundColor(.primary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.tertiary, in: Capsule())
            
            Text(info.resolution)
                .font(.system(size: 11))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: 120)
            
            if !info.refreshRate.isEmpty {
                Text(info.refreshRate)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .frame(maxWidth: 120)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Display Info Model

struct DisplayInfo: Identifiable {
    let id: UUID
    let name: String
    let resolution: String
    let refreshRate: String
    let connectionType: DisplayConnectionType
    let image: NSImage

    init(
        id: UUID = UUID(),
        name: String,
        resolution: String,
        refreshRate: String,
        connectionType: DisplayConnectionType,
        image: NSImage
    ) {
        self.id = id
        self.name = name
        self.resolution = resolution
        self.refreshRate = refreshRate
        self.connectionType = connectionType
        self.image = image
    }
}

// MARK: - View Model

enum DisplaysViewModel {
    
    static func buildDisplayList() -> [DisplayInfo] {
        let collector = HardwareCollector.shared
        let count = collector.numberOfDisplays
        guard count > 0 else { return [] }

        let activeIDs = fetchActiveDisplayIDs()
        let profilerConnectionTypes = fetchProfilerConnectionTypes()
        var result: [DisplayInfo] = []
        
        for i in 0 ..< count {
            let rawName = collector.displayNames.indices.contains(i) ? collector.displayNames[i] : "Display \(i + 1)"
            let rawRes = collector.displayRes.indices.contains(i) ? collector.displayRes[i] : ""
            let rawRefreshRate = collector.displayRefreshRates.indices.contains(i) ? collector.displayRefreshRates[i] : ""
            
            let trimName = trimDisplayName(rawName)
            let trimRes = removeParentheses(rawRes)
            
            var rawConnection = profilerConnectionTypes.indices.contains(i) ? profilerConnectionTypes[i] : ""
            if rawConnection.isEmpty, activeIDs.indices.contains(i) {
                let displayID = activeIDs[i]
                rawConnection = fetchConnectionType(for: displayID)
            }
            if rawConnection.isEmpty {
                rawConnection = "Unknown"
            }
            
            let lowerName = trimName.lowercased()
            
            // Completely eliminate the "Unknown" status for external screens
            if rawConnection == "Unknown" {
                if lowerName.contains("tv") {
                    rawConnection = "HDMI"
                } else if lowerName.contains("sidecar") {
                    rawConnection = "Sidecar"
                } else if lowerName.contains("airplay") {
                    rawConnection = "AirPlay"
                } else {
                    // We extract the hertz (for example, "60.00 Hz" -> 60.0)
                    let cleanRefresh = rawRefreshRate.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
                    let hzValue = Double(cleanRefresh) ?? 60.0
                    
                    if hzValue > 61.0 {
                        rawConnection = "DisplayPort"
                    } else if lowerName.contains("dell") {
                        // Specific hardcoded for the SE/E series from Dell without a DP port
                        rawConnection = "HDMI"
                    } else {
                        // Universal fallback for other standard 60Hz monitors
                        rawConnection = "HDMI / DisplayPort"
                    }
                }
            }
            
            let connectionType = DisplayConnectionType(rawString: rawConnection)
            let image = displayImage(for: trimName, index: i, hasBuiltIn: collector.hasBuiltInDisplay)
            
            let display = DisplayInfo(
                name: trimName,
                resolution: trimRes,
                refreshRate: rawRefreshRate,
                connectionType: connectionType,
                image: image
            )
            result.append(display)
        }
        return result
    }
    
    private static func fetchActiveDisplayIDs() -> [CGDirectDisplayID] {
        let maxDisplays: UInt32 = 16
        var activeDisplays = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
        var displayCount: UInt32 = 0
        
        let result = CGGetActiveDisplayList(maxDisplays, &activeDisplays, &displayCount)
        if result == .success {
            return Array(activeDisplays[0..<Int(displayCount)])
        }
        return []
    }

    private static func fetchProfilerConnectionTypes() -> [String] {
        guard let content = HardwareCollector.shared.getCachedFileContent(InitGlobVar.scrFilePath) else {
            return []
        }

        let lines = content.components(separatedBy: .newlines)
        var inDisplaysSection = false
        var foundDisplayBlock = false
        var currentConnection = ""
        var results: [String] = []

        func finishCurrentDisplay() {
            guard foundDisplayBlock else { return }
            results.append(currentConnection)
            foundDisplayBlock = false
            currentConnection = ""
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed == "Displays:" {
                finishCurrentDisplay()
                inDisplaysSection = true
                continue
            }

            if inDisplaysSection, !trimmed.isEmpty,
               !line.hasPrefix("        "), !line.hasPrefix("\t")
            {
                finishCurrentDisplay()
                inDisplaysSection = false
            }

            guard inDisplaysSection, !trimmed.isEmpty else { continue }

            if trimmed.hasSuffix(":"), !trimmed.contains(": ") {
                finishCurrentDisplay()
                foundDisplayBlock = true
                continue
            }

            guard foundDisplayBlock, currentConnection.isEmpty else { continue }

            if let connection = fieldValue(after: "Connection Type:", in: trimmed), !connection.isEmpty {
                currentConnection = connection
            } else if let displayType = fieldValue(after: "Display Type:", in: trimmed), !displayType.isEmpty {
                currentConnection = displayType
            }
        }

        finishCurrentDisplay()
        return results
    }
    
    private static func fetchConnectionType(for displayID: CGDirectDisplayID) -> String {
        if CGDisplayIsBuiltin(displayID) == 1 {
            return "LVDS / eDP (Built-in display"
        }
        
        let vendorID = CGDisplayVendorNumber(displayID)
        let modelID = CGDisplayModelNumber(displayID)
        let serialNum = CGDisplaySerialNumber(displayID)
        
        let matching = IOServiceMatching("IOFramebuffer")
        var iterator: io_iterator_t = 0
        
        guard IOServiceGetMatchingServices(0, matching, &iterator) == KERN_SUCCESS else {
            return "Unknown"
        }
        
        var connectionType = "Unknown"
        var service = IOIteratorNext(iterator)
        
        while service != 0 {
            var info: Unmanaged<CFMutableDictionary>?
            
            if IORegistryEntryCreateCFProperties(service, &info, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let dict = info?.takeRetainedValue() as? [String: Any] {
                
                if let displayAttributes = dict["IODisplayAttributes"] as? [String: Any] {
                    let serviceVendor = displayAttributes["DisplayVendorID"] as? UInt32 ?? 0
                    let serviceModel = displayAttributes["DisplayProductID"] as? UInt32 ?? 0
                    let serviceSerial = displayAttributes["DisplaySerialNumber"] as? UInt32 ?? 0
                    
                    if serviceVendor == vendorID && serviceModel == modelID && serviceSerial == serialNum {
                        if let connectorType = extractConnectorType(from: dict) {
                            connectionType = parseConnectorType(connectorType)
                            IOObjectRelease(service)
                            break
                        }
                    }
                }
            }
            
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        
        IOObjectRelease(iterator)
        return connectionType
    }

    private static func extractConnectorType(from dict: [String: Any]) -> UInt32? {
        for key in ["IOConnectorType", "connector-type"] {
            guard let rawValue = dict[key] else { continue }
            if let connectorType = parseConnectorTypeValue(rawValue) {
                return connectorType
            }
        }
        return nil
    }

    private static func parseConnectorTypeValue(_ value: Any) -> UInt32? {
        switch value {
        case let connectorType as UInt32:
            return connectorType
        case let connectorType as Int:
            return UInt32(truncatingIfNeeded: connectorType)
        case let connectorType as NSNumber:
            return connectorType.uint32Value
        case let connectorType as Data:
            return parseConnectorTypeData(connectorType)
        case let connectorType as NSData:
            return parseConnectorTypeData(connectorType as Data)
        case let connectorType as String:
            let trimmed = connectorType.trimmingCharacters(in: .whitespacesAndNewlines)
            if let value = UInt32(trimmed, radix: 10) {
                return value
            }
            let hex = trimmed.replacingOccurrences(of: "0x", with: "")
            return UInt32(hex, radix: 16)
        default:
            return nil
        }
    }

    private static func parseConnectorTypeData(_ data: Data) -> UInt32? {
        guard data.count >= 4 else { return nil }

        let bytes = Array(data.prefix(4))
        let littleEndian =
            UInt32(bytes[0]) |
            (UInt32(bytes[1]) << 8) |
            (UInt32(bytes[2]) << 16) |
            (UInt32(bytes[3]) << 24)

        if parseConnectorType(littleEndian) != "Unknown" {
            return littleEndian
        }

        let bigEndian =
            UInt32(bytes[3]) |
            (UInt32(bytes[2]) << 8) |
            (UInt32(bytes[1]) << 16) |
            (UInt32(bytes[0]) << 24)

        if parseConnectorType(bigEndian) != "Unknown" {
            return bigEndian
        }

        return littleEndian
    }

    private static func fieldValue(after label: String, in line: String) -> String? {
        guard let range = line.range(of: label) else { return nil }
        return String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
    }
    
    private static func parseConnectorType(_ type: UInt32) -> String {
        if (type & 0x00000400) != 0 { return "DisplayPort" }
        if (type & 0x00000800) != 0 { return "HDMI" }
        if (type & 0x00000002) != 0 { return "LVDS / eDP (Built-in display)" }
        
        switch type {
        case 0x00000001: return "Dummy (Disabled)"
        case 0x00000004: return "S-Video"
        case 0x00000008: return "VGA"
        case 0x00000010: return "Dual-Link DVI"
        case 0x00000100: return "Composite"
        case 0x00000200: return "Single-Link DVI (DVI-D / DVI-I)"
        case 0x00002000: return "Apple Display Connector (ADC)"
        default: return "Unknown"
        }
    }
}


// MARK: - Connection Type Enum

enum DisplayConnectionType: String {
    case builtIn = "Built-In display"
    case hdmi = "HDMI"
    case displayPort = "DisplayPort"
    case thunderbolt = "Thunderbolt"
    case usbC = "USB-C"
    case airPlay = "AirPlay"
    case sidecar = "Sidecar"
    case vga = "VGA"
    case dvi = "DVI"
    case virtual = "Virtual display"
    case unknown = "Unknown type"
    
    var description: String {
        switch self {
        case .builtIn:
            return NSLocalizedString("displays.connection.builtIn", comment: "Built-in/integrated display connection type")
        case .virtual:
            return NSLocalizedString("displays.connection.virtual", comment: "Virtual display connection type")
        case .unknown:
            return NSLocalizedString("displays.connection.unknown", comment: "Unknown display connection type")
        default:
            return self.rawValue
        }
    }
    
    init(rawString: String) {
        let lower = rawString.lowercased()

        // Quick check for an empty string
        if lower.isEmpty {
            self = .unknown
            return
        }

        if lower.contains("/") {
            let matchedTypes = [
                lower.contains("hdmi"),
                lower.contains("displayport"),
                lower.contains("dvi"),
                lower.contains("thunderbolt"),
                lower.contains("usb-c") || lower.contains("type-c") || lower.contains("typec")
            ].filter { $0 }.count

            if matchedTypes > 1 {
                self = .unknown
                return
            }
        }

        // Apple Silicon Embedded Displays
        if lower.contains("built") ||
           lower.contains("internal") ||
           lower.contains("lcd") ||
           lower.contains("apple-display") ||
           lower.contains("wswm") {
            self = .builtIn
            return
        }

        // Thunderbolt & Type-C (Higher priority as DP/HDMI can go over them)
        if lower.contains("thunderbolt") || lower.contains("tbt") {
            self = .thunderbolt
            return
        }

        if lower.contains("usb") || lower.contains("type-c") || lower.contains("typec") {
            self = .usbC
            return
        }

        // Standard digital interfaces
        if lower.contains("hdmi") {
            self = .hdmi
            return
        }

        if lower.contains("displayport") || lower.contains("dp") {
            self = .displayPort
            return
        }

        // Apple Continuity (Ecosystem)
        if lower.contains("airplay") {
            self = .airPlay
            return
        }

        if lower.contains("sidecar") || lower.contains("ipad") {
            self = .sidecar
            return
        }

        // Virtual displays and software layers
        if lower.contains("virtual") ||
           lower.contains("splashtop") ||
           lower.contains("duet") ||
           lower.contains("displaylink") ||
           lower.contains("null") ||
           lower.contains("mirror") {
            self = .virtual
            return
        }

        // Legacy analog interfaces (for older docking stations)
        if lower.contains("vga") {
            self = .vga
            return
        }

        if lower.contains("dvi") {
            self = .dvi
            return
        }

        // 8. Fallback case
        self = .unknown
    }
}

// MARK: - Helpers

extension DisplaysViewModel {
    
    private static func trimDisplayName(_ name: String) -> String {
        let cleanName = removeParentheses(name)
        
        // Removed .anchored to search for a word in any part of the string
        if let range = cleanName.range(of: "display", options: [.caseInsensitive]) {
            // A substring from the beginning to the end of the word "display" inclusive
            let substring = cleanName[..<range.upperBound]
            return String(substring).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return cleanName
    }

    private static func removeParentheses(_ text: String) -> String {
        // Regular expressions in ReplacingOccurrences are recompiled for each call.
        // For a couple of screens this is not critical, but for optimization it is better to clear the spaces at the end.
        return text.replacingOccurrences(of: "\\([^)]+\\)", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func displayImage(for name: String, index: Int, hasBuiltIn: Bool) -> NSImage {
        let lowerName = name.lowercased()
        
        // System icon in case the asset is not found in the bundle
        let fallbackImage = NSImage(systemSymbolName: "display", accessibilityDescription: nil) ?? NSImage()
        
        // The first display is built-in: iMac or MacBook
        if index == 0 && hasBuiltIn {
            let imageName = lowerName.contains("imac")
                ? genericImacImageNameForCurrentOS()
                : genericMacBookImageNameForCurrentOS()
            
            return NSImage(named: imageName) ?? fallbackImage
        }
        
        // External displays or Sidecar (iPad)
        if lowerName.contains("sidecar") {
            return NSImage(named: "iPad") ?? fallbackImage
        }
        
        return NSImage(named: genericLCDImageNameForCurrentOS()) ?? fallbackImage
    }
    
    // MARK: - OS Version Mapping
    
    private static func genericImacImageNameForCurrentOS() -> String {
        switch HCVersion.shared.osVersion {
        case .bigSur:
            return "genericImacBigSur"
        case .monterey:
            return "genericImacMonterey"
        case .ventura:
            return "genericImacVentura"
        case .sonoma:
            return "genericImacSonoma"
        case .sequoia:
            return "genericImacSequoia"
        case .tahoe:
            return "genericImacTahoe"
        case .goldengate:
            return "genericImacGoldenGate"
        case .unknown:
            return "genericImac"
        }
    }

    private static func genericLCDImageNameForCurrentOS() -> String {
        switch HCVersion.shared.osVersion {
        case .bigSur:
            return "genericLCDBigSur"
        case .monterey:
            return "genericLCDMonterey"
        case .ventura:
            return "genericLCDVentura"
        case .sonoma:
            return "genericLCDSonoma"
        case .sequoia:
            return "genericLCDSequoia"
        case .tahoe:
            return "genericLCDTahoe"
        case .goldengate:
            return "genericLCDGoldenGate"
        case .unknown:
            return "genericLCD"
        }
    }
    
    private static func genericMacBookImageNameForCurrentOS() -> String {
        switch HCVersion.shared.osVersion {
        case .bigSur:
            return "genericMacBookBigSur"
        case .monterey:
            return "genericMacBookMonterey"
        case .ventura:
            return "genericMacBookVentura"
        case .sonoma:
            return "genericMacBookSonoma"
        case .sequoia:
            return "genericMacBookSequoia"
        case .tahoe:
            return "genericMacBookTahoe"
        case .goldengate:
            return "genericMacBookGoldenGate"
        case .unknown:
            return "genericMacBook"
        }
    }
}

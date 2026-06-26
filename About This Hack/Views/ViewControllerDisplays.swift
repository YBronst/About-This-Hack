//
//  ViewControllerDisplays.swift
//  About This Hack
//
//  SwiftUI Displays tab: shows connected displays with icons, names and resolutions.
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
            Divider()
            HStack {
                Spacer()
                Button(NSLocalizedString("displays.preferences", comment: "Display Preferences button")) {
                    openDisplayPreferences()
                }
                Spacer()
            }
            .padding(.vertical, 12)
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
                ScrollView(.horizontal, showsIndicators: displays.count >= 4) {
                    HStack(alignment: .top, spacing: 32) {
                        ForEach(displays) { info in
                            DisplayCard(info: info)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 38)
                    .frame(minWidth: geometry.size.width, alignment: .center)
                }
            }
            .frame(height: 250)
        }
    }

    private func openDisplayPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.displays") {
            NSWorkspace.shared.open(url)
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
                .frame(width: 132, height: 132)
            Text(info.name)
                .font(.system(size: 13, weight: .medium))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: 120)
            Text(info.resolution)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
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
    }
}

// MARK: - Display Info Model

struct DisplayInfo: Identifiable {
    let id: Int
    let name: String
    let resolution: String
    let refreshRate: String
    let image: NSImage
}

// MARK: - View Model

enum DisplaysViewModel {
    static func buildDisplayList() -> [DisplayInfo] {
        let collector = HardwareCollector.shared
        let count = collector.numberOfDisplays
        guard count > 0 else { return [] }

        var result: [DisplayInfo] = []
        for i in 0 ..< count {
            let rawName = i < collector.displayNames.count ? collector.displayNames[i] : "Display \(i + 1)"
            let rawRes = i < collector.displayRes.count ? collector.displayRes[i] : ""
            let rawRefreshRate = i < collector.displayRefreshRates.count ? collector.displayRefreshRates[i] : ""
            let trimName = trimDisplayName(rawName)
            let trimRes = removeParentheses(rawRes)
            let image = displayImage(for: trimName, index: i, hasBuiltIn: collector.hasBuiltInDisplay)
            result.append(DisplayInfo(id: i, name: trimName, resolution: trimRes, refreshRate: rawRefreshRate, image: image))
        }
        return result
    }

    // MARK: - Helpers

    private static func trimDisplayName(_ name: String) -> String {
        let withoutParens = removeParentheses(name)
        if let range = withoutParens.range(of: "display", options: .caseInsensitive) {
            return String(withoutParens[..<range.upperBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return withoutParens.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func removeParentheses(_ text: String) -> String {
        text.replacingOccurrences(of: "\\([^)]+\\)", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func displayImage(for name: String, index: Int, hasBuiltIn: Bool) -> NSImage {
        // First display that's a built-in: use macbook icon
        if index == 0 && hasBuiltIn {
            return NSImage(named: "MacBook") ?? NSImage()
        }
        let lower = name.lowercased()
        let named: String
        switch lower {
//        case let n where n.contains("imac"):
//            named = "NSComputer"
        case let n where n.contains("lg") && (n.contains("hdr") || n.contains("4k")):
            named = "LG4K"
        case let n where n.contains("sidecar"):
            named = "iPad"
        case let n where n.contains("led") && n.contains("cinema"):
            named = "AppleDisplay"
        case let n where n.contains("built"):
            named = "MacBook"
        default:
            named = genericLCDImageNameForCurrentOS()
        }
        return NSImage(named: named) ?? NSImage()
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
    
}

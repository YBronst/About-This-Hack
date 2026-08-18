//
//  ViewController.swift
//  About This Hack
//
//  SwiftUI Overview tab: macOS logo, version info, hardware specs, action buttons.
//

import AppKit
import SwiftUI

// MARK: - Overview View

struct OverviewView: View {
    @StateObject private var viewModel = OverviewViewModel()
    @EnvironmentObject private var appState: AppState

    var body: some View {
        let sidebarVisible = appState.isSidebarVisible
        VStack(alignment: .leading, spacing: 0) {
            headerSection
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, alignment: sidebarVisible ? .leading : .center)

            Divider()

            specsSection
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: sidebarVisible ? .leading : .center)

            Divider()

            footerSection
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onReceive(NotificationCenter.default.publisher(for: .customLogoDidChange)) { _ in
            viewModel.reloadLogo()
        }
    }

    // MARK: - Header (logo + OS info)

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 20) {
            Image(nsImage: viewModel.logoImage)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 96, height: 96)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)

            VStack(alignment: .leading, spacing: 5) {
                Text(viewModel.osFullName)
                    .font(.system(size: 22, weight: .semibold))
                Text(viewModel.systemVersion)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .help(viewModel.osVersionTooltip)
                Text(viewModel.macModel)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .help(viewModel.macModelTooltip)
            }
            .padding(.top, 8)

            if appState.isSidebarVisible {
                Spacer()
            }
        }
    }

    // MARK: - Specs Table

    private var specsSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            SpecRow(
                label: NSLocalizedString("spec.processor", comment: "Processor label"),
                value: viewModel.cpu,
                tooltip: viewModel.cpuTooltip
            )
            SpecRow(
                label: NSLocalizedString("spec.memory", comment: "Memory label"),
                value: viewModel.ram,
                tooltip: viewModel.ramTooltip
            )
            SpecRow(
                label: NSLocalizedString("spec.graphics", comment: "Graphics label"),
                value: viewModel.graphics,
                tooltip: viewModel.graphicsTooltip
            )
            SpecRow(
                label: NSLocalizedString("spec.display", comment: "Display label"),
                value: viewModel.display,
                tooltip: viewModel.displayTooltip
            )
            SpecRow(
                label: NSLocalizedString("spec.startup_disk", comment: "Startup Disk label"),
                value: viewModel.startupDisk,
                tooltip: viewModel.startupDiskTooltip
            )
            SerialRow(viewModel: viewModel)
            SpecRow(
                label: NSLocalizedString("spec.bootloader", comment: "Bootloader label"),
                value: viewModel.bootloader,
                tooltip: viewModel.bootloaderTooltip
            )
        }
    }

    // MARK: - Footer (buttons + credits)

    private var footerSection: some View {
        HStack(spacing: 10) {
            VStack(spacing: 8) {
                Button(NSLocalizedString("button.system_report", comment: "System Report button")) {
                    viewModel.showSystemReport()
                }
                .buttonStyle(.bordered)
                .help(viewModel.systemReportButtonTooltip)
                Button(NSLocalizedString("button.software_update", comment: "Software Update button")) {
                    viewModel.showSoftwareUpdate()
                }
                .buttonStyle(.bordered)
                .help(viewModel.softwareUpdateButtonTooltip)
            }
            Spacer()
            Text(NSLocalizedString("credits.text", comment: "Credits text"))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Spec Row

private struct SpecRow: View {
    let label: String
    let value: String
    let tooltip: String

    private let labelWidth: CGFloat = 154

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .frame(width: labelWidth, alignment: .trailing)
                .padding(.trailing, 8)
            Text(value)
                .font(.system(size: 13))
                .help(tooltip)
        }
    }
}

// MARK: - Serial Row (with show/hide toggle)

private struct SerialRow: View {
    @ObservedObject var viewModel: OverviewViewModel

    private let labelWidth: CGFloat = 154

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(NSLocalizedString("spec.serial_number", comment: "Serial Number label"))
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .frame(width: labelWidth, alignment: .trailing)
                .padding(.trailing, 8)

            if viewModel.isSerialHidden {
                Text(String(repeating: "•", count: 11))
                    .font(.system(size: 13))
            } else {
                Text(viewModel.serialNumber)
                    .font(.system(size: 13))
                    .help(viewModel.serialTooltip)
            }

            Button(action: { viewModel.isSerialHidden.toggle() }) {
                Image(systemName: viewModel.isSerialHidden ? "eye.slash" : "eye")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.leading, 6)
            .help(viewModel.serialTooltip)
        }
    }
}

// MARK: - View Model

class OverviewViewModel: ObservableObject {
    @Published var logoImage: NSImage = .init()
    @Published var isSerialHidden: Bool = true

    let osFullName: String
    let systemVersion: String
    let macModel: String
    let cpu: String
    let ram: String
    let graphics: String
    let display: String
    let startupDisk: String
    let serialNumber: String
    let bootloader: String

    let osVersionTooltip: String
    let macModelTooltip: String
    let cpuTooltip: String
    let ramTooltip: String
    let graphicsTooltip: String
    let displayTooltip: String
    let startupDiskTooltip: String
    let serialTooltip: String
    let bootloaderTooltip: String
    let systemReportButtonTooltip: String
    let softwareUpdateButtonTooltip: String

    private let defaults = UserDefaults.standard

    init() {
        let t = Tooltips.shared

        osFullName = "\(HCVersion.shared.osPrefix) \(HCVersion.shared.osName)"
        systemVersion = "\(HCVersion.shared.osNumber) (\(HCVersion.shared.osBuildNumber))"

        let macName = HCMacModel.shared.macName
        let modelID = HCMacModel.shared.getModelIdentifier()
        let fullModel = "\(macName) - \(modelID)"
        macModel = fullModel.count > 60 ? macName : fullModel

        cpu = HCCPU.shared.getCPU()
        ram = HCRAM.shared.getRam()
        graphics = HCGPU.shared.getGPU()
        display = HCDisplay.shared.getDisp()
        startupDisk = HCStartupDisk.shared.getStartupDisk()
        serialNumber = HCSerialNumber.shared.getSerialNumber()
        bootloader = HCBootloader.shared.getBootloader()

        osVersionTooltip = t.osVersiontoolTip
        macModelTooltip = t.macModeltoolTip
        cpuTooltip = t.cputoolTip
        ramTooltip = t.ramtoolTip
        graphicsTooltip = t.graphicstoolTip
        displayTooltip = t.displaytoolTip
        startupDiskTooltip = t.startupDisktoolTip
        serialTooltip = t.serialToggletoolTip
        bootloaderTooltip = t.blVersiontoolTip
        systemReportButtonTooltip = t.btSysInfotoolTip
        softwareUpdateButtonTooltip = t.btSoftUpdtoolTip

        reloadLogo()
    }

    func reloadLogo() {
        if let path = defaults.string(forKey: CustomLogoConstants.customLogoPathKey),
           let image = NSImage(contentsOfFile: path)
        {
            logoImage = image
        } else {
            logoImage = NSImage(named: HCVersion.shared.getOSImageName()) ?? NSImage()
        }
    }

    func showSystemReport() {
        NSWorkspace.shared.open(URL(fileURLWithPath: InitGlobVar.systemReportSP))
    }

    func showSoftwareUpdate() {
        let majorVersion = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        if majorVersion >= 13, let url = URL(string: InitGlobVar.softwareUpdateURL) {
            NSWorkspace.shared.open(url)
        }
    }
}

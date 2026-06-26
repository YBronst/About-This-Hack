//
//  ContentView.swift
//  About This Hack
//
//  Main SwiftUI view: fake-sidebar navigation (custom HStack layout).
//  Uses a plain HStack with a fixed-width sidebar panel and a detail panel
//  instead of NavigationSplitView, which had persistent tap-event issues on
//  macOS Tahoe.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.isDataLoaded {
                FakeSidebarLayout()
            } else {
                LoadingView()
            }
        }
        .frame(minWidth: 680, minHeight: 420)
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.4)
            Text(NSLocalizedString("loading.data.message", comment: "Loading data message"))
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Fake Sidebar Layout

//
// Replaces NavigationSplitView with a plain HStack so that tap events on the
// sidebar rows are always processed reliably, regardless of macOS version.
// The sidebar rows directly write appState.selectedSection on tap; no Binding
// plumbing or task(id:) synchronisation is needed.

private struct FakeSidebarLayout: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            // ── Sidebar ─────
            if appState.isSidebarVisible {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(AppSection.allCases.filter { appState.shouldShowAudioTab || $0 != .audio }) { section in
                        SidebarRow(
                            section: section,
                            isSelected: appState.selectedSection == section
                        ) {
                            appState.selectedSection = section
                        }
                    }
                    Spacer()
                }
                .padding(.top, 8)
                .padding(.horizontal, 8)
                .frame(width: 180)
                .frame(maxHeight: .infinity)
                .background(Color(NSColor.controlBackgroundColor)) // opaque window
//                .background(.ultraThinMaterial) // transparent window
                .transition(.move(edge: .leading))

                Divider()
                    .transition(.opacity)
            }

            // ── Detail ─────
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(NSColor.controlBackgroundColor)) // opaque window
//        .background(.ultraThinMaterial) // transparent window
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        appState.isSidebarVisible.toggle()
                    }
                } label: {
                    Image(systemName: "sidebar.leading")
                }
                .help(NSLocalizedString("toolbar.toggle_sidebar", comment: "Toggle Sidebar"))
            }
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailView: some View {
        switch appState.selectedSection {
        case .overview, .none:
            OverviewView()
        case .displays:
            DisplaysView()
        case .storage:
            StorageView()
        case .audio:
            if appState.shouldShowAudioTab {
                AudioView()
            } else {
                OverviewView()
            }
        case .support:
            SupportView()
        }
    }
}

// MARK: - Sidebar Row

private struct SidebarRow: View {
    let section: AppSection
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(section.title, systemImage: section.systemImage)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .primary : .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 5)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected
                            ? Color.accentColor.opacity(0.18)
                            : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle()) // tooltips on sidebar items
        .help(section.tooltip)
    }
}

//
//  ContentView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-19.
//

import SwiftUI
import Defaults

struct ContentView: View {
    @Bindable private var appState = AppState.shared
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            ZStack(alignment: .bottomLeading) {
                SidebarView()

                settingsButton
            }
            .frame(minWidth: 200)
        } detail: {
            detail
                .frame(minWidth: 600, minHeight: 500)
        }
    }

    // MARK: ViewBuilder
    @ViewBuilder
    private var detail: some View {
        switch appState.selectedSidebarItem ?? startPageItem {
        case .home: HomeView()
        case .fileUpload: FileView()
        case .urlLookup: URLView()
        case .fileBatch: FileBatchView()
        case .downloadsMonitor: DownloadsMonitorView()
        case .history: ScanHistoryView()
        case .log: LogView()
        }
    }

    private var settingsButton: some View {
        VStack(spacing: 0) {
            Divider()

            SettingsLink {
                Label("menubar.open.settings", systemImage: "gearshape")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 22)
                    .padding(.trailing, 14)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Private
    private var startPageItem: ServiceSidebarItem {
        switch Defaults[.startPage] {
        case .home: .home
        case .file: .fileUpload
        case .url: .urlLookup
        case .fileBatch: .fileBatch
        }
    }
}

 #Preview {
     ContentView()
 }

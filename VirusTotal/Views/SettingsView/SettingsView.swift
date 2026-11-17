//
//  SettingsView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-19.
//

import SwiftUI
import Sparkle

struct SettingsView: View {
    private let updater: SPUUpdater
    @Environment(\.inMenuPanel) private var inMenuPanel
    @State private var selection = 0

    var body: some View {
        Group {
            if inMenuPanel {
                VStack(spacing: 0) {
                    Picker("settings.general", selection: $selection) {
                        Text("settings.general").tag(0)
                        Text("settings.api").tag(1)
                        Text("settings.advanced").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    switch selection {
                    case 0: GeneralTab(updater: updater)
                    case 1: APITab()
                    default: AdvancedTab()
                    }
                }
            } else {
                windowTabs
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var windowTabs: some View {
        TabView {
            GeneralTab(updater: updater)
                .tabItem {
                    Label("settings.general", systemImage: "gear")
                }

            APITab()
                .tabItem {
                    Label("settings.api", systemImage: "key")
                }

            AdvancedTab()
                .tabItem {
                    Label("settings.advanced", systemImage: "gearshape.2")
                }
        }
    }

    // MARK: Internal
    init(updater: SPUUpdater) {
        self.updater = updater
    }
}

//
//  ToolView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-30.
//

import SwiftUI
import Defaults

struct ToolView: View {
    var searchText: String

    init(searchText: String) {
        self.searchText = searchText
    }

    var body: some View {
        Section("sidebar.section.tools") {
            ForEach(filteredItems) { item in
                NavigationLink(destination: viewForSidebarItem(item)) {
                    Label(item.titleKey, systemImage: item.systemImageName)
                }
                .tag(item)
            }
        }
    }

    @ViewBuilder
    private func viewForSidebarItem(_ item: SidebarItem) -> some View {
        switch item {
        case .history:
            ScanHistoryView()
                .frame(minWidth: 600, minHeight: 500)
        case .log:
            LogView()
                .frame(minWidth: 600, minHeight: 500)
        }
    }

    private var filteredItems: [SidebarItem] {
        SidebarItem.filtered(by: searchText, using: \.localizedText)
    }

    private enum SidebarItem: String, CaseIterable, Identifiable {
        case history = "sidebar.history"
        case log = "sidebar.log"

        var id: String { self.rawValue }

        var titleKey: LocalizedStringKey {
            LocalizedStringKey(rawValue)
        }

        var localizedText: String {
            Defaults[.appLanguage].localizedString(forKey: rawValue)
        }

        var systemImageName: String {
            switch self {
            case .history:
                return "book.closed"
            case .log:
                return "doc.text"
            }
        }
    }
}

#Preview {
    ToolView(searchText: "")
}

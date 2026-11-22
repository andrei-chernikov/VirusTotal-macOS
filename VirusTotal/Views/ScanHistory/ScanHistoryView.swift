//
//  ScanHistoryView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-29.
//

import SwiftUI

struct ScanHistoryView: View {
    var compact = false
    @State private var tableSelection: Set<ScanEntry.ID> = []
    @State private var showingClearConfirmation = false
    private var historyManager = ScanHistoryManager.shared

    var body: some View {
        Group {
            if compact && historyManager.scanEntries.isEmpty {
                ContentUnavailableView("menu.history.empty.title", systemImage: "clock.arrow.circlepath",
                                       description: Text("menu.history.empty.description"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if compact {
                List(historyManager.scanEntries) { entry in
                    HStack(alignment: .top) {
                        statusView(flag: entry.result.malicious)
                        VStack(alignment: .leading) {
                            Text(entry.target).lineLimit(2).textSelection(.enabled)
                            Text("\(Text(entry.scanType.rawValue)) · \(entry.result.analysisDate) · \(entry.result.malicious)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(entry.result.reputation)").foregroundStyle(entry.result.reputation < 0 ? .orange : .secondary)
                    }
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            } else {
                historyTable
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                if !historyManager.scanEntries.isEmpty {
                    Button(action: showConfirmClear) { Label("history.toolbar.clear", systemImage: "trash") }
                        .help("history.toolbar.clear.help")
                        .keyboardShortcut(.delete, modifiers: [.command, .shift])
                        .confirmationDialog("history.clear.confirmation.title", isPresented: $showingClearConfirmation) {
                            Button("history.clear.confirmation.clear", role: nil, action: clearHistory)
                            Button("history.clear.confirmation.cancel", role: .cancel) { }
                        } message: { Text("history.clear.confirmation.message") }
                }
            }
        }
    }

    private var historyTable: some View {
        Table(historyManager.scanEntries, selection: $tableSelection) {
            TableColumn("history.status") { entry in
                statusView(flag: entry.result.malicious)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .width(40)
            TableColumn("history.type") { entry in
                Text(entry.scanType.rawValue)
            }
            .width(40)
            TableColumn("history.target", value: \.target)
                .width(min: 40, ideal: 100)
            TableColumn("history.malicious") { entry in
                Text("\(entry.result.malicious)")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundStyle(entry.result.malicious != 0 ? .red : .primary)
            }
            .width(54)
            TableColumn("history.analysis.date", value: \.result.analysisDate)
                .width(79)
            TableColumn("history.community.score") { entry in
                Text("\(entry.result.reputation)")
                    .foregroundStyle(entry.result.reputation < 0 ? .orange : .primary)
            }
            .width(min: 80, ideal: 80)
        }
    }

    // MARK: Private

    /// Clears the ScanEntries
    private func clearHistory() {
        historyManager.scanEntries.removeAll()
        Task {
            do {
                try await historyManager.save(entries: [])
            } catch {
                log.error("Error clearing scan history: \(error)")
            }
        }
    }

    /// Changes `showingClearConfirmation` to true
    private func showConfirmClear() {
        showingClearConfirmation = true
    }

    @ViewBuilder
    private func statusView(flag: Int) -> some View {
        switch flag {
        case 0:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .symbolRenderingMode(.monochrome)
        default:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
                .symbolRenderingMode(.multicolor)
        }
    }
}

#Preview {
    ScanHistoryView()
        .frame(minWidth: 600, minHeight: 500)
}

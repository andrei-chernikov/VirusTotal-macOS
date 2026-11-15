import SwiftUI
import Defaults
import Sparkle

/// The hosting controller stays alive while the popover is hidden, preserving
/// navigation and view state while the shared models continue their work.
struct MenuPanelView: View {
    let updater: SPUUpdater
    @Bindable var router: MenuPanelRouter
    @Bindable private var appState = AppState.shared
    @Default(.appFirstLaunch) private var firstLaunch: Bool
    @State private var showClearHistory = false
    @State private var file = FileViewModel.shared
    @State private var url = URLViewModel.shared
    @State private var batch = FileBatchViewModel.shared
    @State private var monitor = DownloadsMonitorViewModel.shared
    @State private var history = ScanHistoryManager.shared
    @State private var logs = LogManager.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                sectionButton(.fileUpload)
                sectionButton(.urlLookup)
                sectionButton(.fileBatch)
                Menu {
                    ForEach([ServiceSidebarItem.home, .downloadsMonitor, .history, .log]) { item in
                        Button { select(item) } label: { Label(item.titleKey, systemImage: item.systemImageName) }
                    }
                } label: {
                    Label("menu.panel.more", systemImage: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(8)
            Divider()
            panelActions
            NavigationStack {
                Group {
                    if router.showingSettings {
                        SettingsView(updater: updater)
                    } else {
                        content
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            HStack {
                Button { router.showingSettings = true } label: {
                    Label("menubar.open.settings", systemImage: "gearshape")
                }
                Spacer()
                Button("menubar.quit") { NSApp.terminate(nil) }
            }
            .padding(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.inMenuPanel, true)
        .controlSize(.small)
        .confirmationDialog("history.clear.confirmation.title", isPresented: $showClearHistory) {
            Button("history.clear.confirmation.clear") {
                history.scanEntries.removeAll()
                Task {
                    do { try await history.save(entries: []) } catch { log.error("Error clearing scan history: \(error)") }
                }
            }
            Button("history.clear.confirmation.cancel", role: .cancel) { }
        } message: { Text("history.clear.confirmation.message") }
        .sheet(isPresented: $firstLaunch) {
            LaunchView().frame(width: 400, height: 430)
        }
        .onAppear {
            if firstLaunch { NotificationCenter.default.post(name: .menuPanelModalChanged, object: true) }
        }
        .onChange(of: firstLaunch) { _, presented in
            NotificationCenter.default.post(name: .menuPanelModalChanged, object: presented)
        }
        .onChange(of: appState.selectedSidebarItem) {
            router.showingSettings = false
        }
    }

    @ViewBuilder private var panelActions: some View {
        if !router.showingSettings {
            HStack {
                switch currentSection {
                case .fileUpload where file.statusMonitor != nil && file.statusMonitor != .none:
                    Button("fileview.toolbar.back", systemImage: "chevron.left") {
                        file.cancelOngoingRequest()
                        file.statusMonitor = .none
                    }
                    if file.statusMonitor == .success {
                        Button("toolbar.button.rescan", systemImage: "arrow.clockwise") {
                            Task {
                                file.statusMonitor = .loading
                                await file.requestReanalyze()
                            }
                        }
                    }
                case .urlLookup where url.statusMonitor == .success:
                    Button("toolbar.button.rescan", systemImage: "arrow.clockwise") {
                        url.statusMonitor = .loading
                        url.requestReanalyze()
                    }
                case .fileBatch where !batch.batchFiles.isEmpty:
                    Button("filebatchview.clear.help.headline", systemImage: "trash") { batch.clearAllFiles() }
                case .downloadsMonitor where !monitor.scanItems.isEmpty:
                    Button("downloadsmonitor.button.clear", systemImage: "trash") { monitor.clearResults() }
                        .disabled(monitor.hasActiveScanItems)
                case .history where !history.scanEntries.isEmpty:
                    Button("history.toolbar.clear", systemImage: "trash") { showClearHistory = true }
                case .log where !logs.logs.isEmpty:
                    Button("menu.panel.logs.clear", systemImage: "trash") { logs.clearLogs() }
                default:
                    EmptyView()
                }
                Spacer()
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 12)
        }
    }

    private func sectionButton(_ item: ServiceSidebarItem) -> some View {
        Button { select(item) } label: {
            Label(item == .fileBatch ? "menu.panel.batch" : item.titleKey, systemImage: item.systemImageName)
        }
        .buttonStyle(.bordered)
        .tint(!router.showingSettings && appState.selectedSidebarItem == item ? .accentColor : nil)
    }

    private var currentSection: ServiceSidebarItem {
        if let selection = appState.selectedSidebarItem { return selection }
        switch Defaults[.startPage] {
        case .home: return .home
        case .file: return .fileUpload
        case .url: return .urlLookup
        case .fileBatch: return .fileBatch
        }
    }

    private func select(_ item: ServiceSidebarItem) {
        router.showingSettings = false
        appState.selectedSidebarItem = item
    }

    @ViewBuilder private var content: some View {
        switch currentSection {
        case .home: HomeView()
        case .fileUpload: FileView()
        case .urlLookup: URLView()
        case .fileBatch: FileBatchView()
        case .downloadsMonitor: DownloadsMonitorView()
        case .history: ScanHistoryView(compact: true)
        case .log: LogView()
        }
    }
}

private struct InMenuPanelKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var inMenuPanel: Bool {
        get { self[InMenuPanelKey.self] }
        set { self[InMenuPanelKey.self] = newValue }
    }
}

@MainActor
@Observable
final class MenuPanelRouter {
    var showingSettings = false
}

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
    @State private var isFileDropTargeted = false
    @State private var file = FileViewModel.shared
    @State private var url = URLViewModel.shared
    @State private var batch = FileBatchViewModel.shared
    @State private var monitor = DownloadsMonitorViewModel.shared
    @State private var history = ScanHistoryManager.shared

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
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(.bar)
            .onDrop(of: [.fileURL], delegate: fileDropDelegate)
            Divider()
            panelActions
            centralDropArea
            Divider()
            HStack {
                Button { router.showingSettings = true } label: {
                    Label("menubar.open.settings", systemImage: "gearshape")
                }
                Spacer()
                Button("menubar.quit") { NSApp.terminate(nil) }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(.bar)
            .onDrop(of: [.fileURL], delegate: fileDropDelegate)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .overlay {
            if isFileDropTargeted && canAcceptFileDrop {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.accentColor, lineWidth: 2)
                    .padding(4)
                    .overlay(alignment: .top) {
                        Label("menu.panel.drop.hint", systemImage: "doc.badge.arrow.up")
                            .font(.callout.weight(.medium))
                            .padding(10)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                            .padding(.top, 52)
                    }
                    .allowsHitTesting(false)
            }
        }
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
        .onChange(of: router.showingSettings) { _, showing in
            if showing { NotificationCenter.default.post(name: .menuPanelModalChanged, object: false) }
        }
        .onChange(of: appState.selectedSidebarItem) {
            router.showingSettings = false
        }
    }

    private var centralDropArea: some View {
        Group {
            if router.showingSettings {
                SettingsView(updater: updater)
            } else {
                content
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .contentShape(Rectangle())
        .onDrop(of: [.fileURL], delegate: fileDropDelegate)
    }

    private var fileDropDelegate: AnyDropDelegate {
        AnyDropDelegate(
            isTargeted: $isFileDropTargeted,
            onValidate: { canAcceptFileDrop && $0.itemProviders(for: [.fileURL]).count == 1 },
            onPerform: receiveFileDrop,
            onUpdated: { _ in DropProposal(operation: canAcceptFileDrop ? .copy : .forbidden) }
        )
    }

    private var canAcceptFileDrop: Bool { router.canAcceptFileDrop }

    private func receiveFileDrop(_ info: DropInfo) -> Bool {
        let providers = info.itemProviders(for: [.fileURL])
        guard canAcceptFileDrop, providers.count == 1, let provider = providers.first else { return false }
        isFileDropTargeted = false
        router.isReceivingFileDrop = true
        Task { @MainActor in
            let fileURL = await provider.fileURL()
            router.isReceivingFileDrop = false
            guard let fileURL else {
                select(.fileUpload)
                file.errorMessage = String(localized: "menu.panel.drop.error")
                file.statusMonitor = .fail
                return
            }
            router.acceptFileDrop(fileURL)
        }
        return true
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
                    .padding(.vertical, 6)
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
        let selected = !router.showingSettings && currentSection == item
        return Button { select(item) } label: {
            Label(item == .fileBatch ? "menu.panel.batch" : item.titleKey, systemImage: item.systemImageName)
                .foregroundStyle(.primary)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(selected ? Color.accentColor.opacity(0.2) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 7))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
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
    var isReceivingFileDrop = false

    var canAcceptFileDrop: Bool {
        guard !Defaults[.appFirstLaunch], !isReceivingFileDrop else { return false }
        switch FileViewModel.shared.statusMonitor {
        case .none, .upload, .success, .fail: return true
        default: return false
        }
    }

    @discardableResult
    func acceptFileDrop(_ url: URL) -> Bool {
        guard url.isFileURL, canAcceptFileDrop else { return false }
        isReceivingFileDrop = true
        showingSettings = false
        AppState.shared.selectedSidebarItem = .fileUpload
        NSApp.activate(ignoringOtherApps: true)
        let task = FileViewModel.shared.startFileImport(url)
        Task { @MainActor in
            await task.value
            isReceivingFileDrop = false
        }
        return true
    }
}

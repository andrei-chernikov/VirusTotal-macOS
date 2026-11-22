//
//  DownloadsMonitorView.swift
//  VirusTotal
//

import AppKit
import SwiftUI
import Defaults

struct DownloadsMonitorView: View {
    @State private var viewModel = DownloadsMonitorViewModel.shared
    @State private var isFolderImporterPresented = false
    @State private var isScanExistingConfirmationPresented = false
    @State private var isAutoScanConsentPresented = false
    @State private var isFileTypeSettingsPresented = false
    @State private var shouldEnableAfterFolderSelection = false
    @State private var existingFileCount = 0

    @Environment(\.inMenuPanel) private var inMenuPanel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .fileImporter(
            isPresented: $isFolderImporterPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleFolderImporterResult(result)
        }
        .confirmationDialog(
            "downloadsmonitor.scanexisting.alert.title",
            isPresented: $isScanExistingConfirmationPresented
        ) {
            Button("downloadsmonitor.scanexisting.alert.confirm \(existingFileCount)", role: nil) {
                viewModel.scanExistingFiles()
            }
            Button("common.cancel", role: .cancel) { }
        } message: {
            Text("downloadsmonitor.scanexisting.alert.message")
        }
        .confirmationDialog(
            "downloadsmonitor.autoscan.alert.title",
            isPresented: $isAutoScanConsentPresented
        ) {
            Button("downloadsmonitor.autoscan.alert.confirm", role: nil) {
                Defaults[.didConfirmAutoScanUploads] = true
                viewModel.setMonitoringEnabled(true)
            }
            Button("common.cancel", role: .cancel) { }
        } message: {
            Text("downloadsmonitor.autoscan.alert.message")
        }
        .toolbar {
            if !inMenuPanel && !viewModel.scanItems.isEmpty {
                ToolbarItem {
                    Button(action: viewModel.clearResults) {
                        Image(systemName: "trash")
                    }
                    .disabled(viewModel.hasActiveScanItems)
                    .help("downloadsmonitor.button.clear")
                }
            }
        }
        .onChange(of: isFolderImporterPresented) { _, presented in
            NotificationCenter.default.post(name: .menuPanelModalChanged, object: presented)
        }
        .onAppear {
            viewModel.startIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .downloadsMonitorFileRequested)) { notification in
            viewModel.handleNotificationSelection(filePath: notification.userInfo?["filePath"] as? String)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: inMenuPanel ? 6 : 16) {
            HStack(alignment: .center, spacing: inMenuPanel ? 6 : 12) {
                Image(systemName: "folder.badge.gearshape")
                    .font(.system(size: inMenuPanel ? 16 : 34))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: inMenuPanel ? 20 : 44)

                VStack(alignment: .leading, spacing: inMenuPanel ? 2 : 4) {
                    Text("sidebar.downloadsmonitor")
                        .font(inMenuPanel ? .headline : .title2)
                        .fontWeight(.semibold)
                    Text(viewModel.statusMessage)
                        .font(inMenuPanel ? .caption : .subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 4)

                Toggle("downloadsmonitor.autoscan.toggle", isOn: Binding(
                    get: { viewModel.isEnabled },
                    set: { enabled in
                        if enabled {
                            requestEnableAutoScan()
                        } else {
                            viewModel.setMonitoringEnabled(false)
                        }
                    }
                ))
                .toggleStyle(.switch)
            }

            HStack(spacing: inMenuPanel ? 6 : 10) {
                Button("downloadsmonitor.button.choose_folder", systemImage: "folder.badge.plus") {
                    isFolderImporterPresented = true
                }

                Button {
                    isFileTypeSettingsPresented.toggle()
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
                .popover(isPresented: $isFileTypeSettingsPresented) {
                    fileTypeSettings
                }
                .help("downloadsmonitor.filetypes.button")

                Button("downloadsmonitor.button.scan_existing", systemImage: "arrow.triangle.2.circlepath") {
                    confirmScanExistingIfNeeded()
                }

                Spacer(minLength: 0)

                if inMenuPanel {
                    PanelClearButton(
                        title: "downloadsmonitor.button.clear",
                        disabled: viewModel.scanItems.isEmpty || viewModel.hasActiveScanItems,
                        action: viewModel.clearResults
                    )
                }
            }
        }
        .padding(.horizontal, inMenuPanel ? 12 : 20)
        .padding(.vertical, inMenuPanel ? 4 : 20)
    }

    private var fileTypeSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("downloadsmonitor.filetypes.title")
                .font(.headline)

            ForEach(DownloadMonitorFileCategory.allCases) { category in
                Toggle(isOn: Binding(
                    get: { viewModel.selectedFileCategories.contains(category) },
                    set: { viewModel.setFileCategory(category, isEnabled: $0) }
                )) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(category.localizedTitle)
                        Text(verbatim: "(\(category.extensionExamples))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .lineLimit(1)
                }
            }
        }
        .padding()
        .frame(width: 340)
    }

    @ViewBuilder
    private var content: some View {
        if inMenuPanel && viewModel.scanItems.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Label("downloadsmonitor.empty.title", systemImage: "tray")
                    .font(.callout.weight(.semibold))
                Text("menu.monitor.empty.description")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if viewModel.scanItems.isEmpty {
            ContentUnavailableView(
                "downloadsmonitor.empty.title",
                systemImage: "tray",
                description: Text("downloadsmonitor.autoscan.footnote")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(viewModel.scanItems) { item in
                DownloadsMonitorRowView(
                    item: item,
                    isSelected: viewModel.selectedFilePath == item.originalFileURL.path
                )
            }
            .listStyle(.plain)
        }
    }

    private func handleFolderImporterResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            viewModel.setFolderURL(url)
            if shouldEnableAfterFolderSelection {
                shouldEnableAfterFolderSelection = false
                requestEnableAutoScan()
            }
        case .failure(let error):
            shouldEnableAfterFolderSelection = false
            log.error("Downloads monitor folder selection failed: \(error)")
        }
    }

    private func requestEnableAutoScan() {
        guard viewModel.hasSavedFolderAccess else {
            shouldEnableAfterFolderSelection = true
            isFolderImporterPresented = true
            return
        }

        if Defaults[.didConfirmAutoScanUploads] {
            viewModel.setMonitoringEnabled(true)
        } else {
            isAutoScanConsentPresented = true
        }
    }

    private func confirmScanExistingIfNeeded() {
        existingFileCount = viewModel.eligibleFileCount()
        guard existingFileCount > 0 else { return }

        isScanExistingConfirmationPresented = true
    }
}

private struct DownloadsMonitorRowView: View {
    let item: DownloadScanItem
    let isSelected: Bool
    @State private var showErrorPopover = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 22))
                .foregroundStyle(iconColor)
                .frame(width: 30, height: 35)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.fileName)
                    .font(.headline)
                    .lineLimit(1)
                Text(item.fileSize.chooseUnit())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            statusView
            Button(action: openInFinder) {
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("downloadsmonitor.menu.show_in_finder")

            Button(action: openOnVirusTotal) {
                Image(systemName: "arrow.up.forward.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(item.sha256.isEmpty)
            .help("downloadsmonitor.menu.open_vt")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isSelected ? Color.accentColor.opacity(0.16) : Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    @ViewBuilder
    private var statusView: some View {
        switch item.status {
        case .queued:
            Text("downloadsmonitor.status.queued.label")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .preparing, .analyzing:
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.small)
                Text(item.status == .preparing
                     ? "downloadsmonitor.status.preparing"
                     : "downloadsmonitor.status.analyzing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .uploading:
            VStack(alignment: .trailing, spacing: 4) {
                ProgressView(value: item.uploadProgress)
                    .frame(width: 70)
                Text(item.uploadProgress, format: .percent)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        case .success:
            if let stats = item.analysisStats {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(stats.malicious > 0 || stats.suspicious > 0 ? "downloadsmonitor.status.detected" : "downloadsmonitor.status.clean")
                        .font(.caption)
                        .foregroundStyle(stats.malicious > 0 || stats.suspicious > 0 ? .red : .green)
                    Text("\(stats.malicious + stats.suspicious)/\(stats.allFlags.sum { $0 })")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .popover(isPresented: $showErrorPopover) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("downloadsmonitor.status.failed")
                            .font(.headline)
                        Text(item.errorMessage ?? "Unknown error")
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .frame(width: 240)
                }
                .onTapGesture {
                    showErrorPopover.toggle()
                }
        }
    }

    private var iconName: String {
        switch item.status {
        case .success:
            "checkmark.circle.fill"
        case .failed:
            "exclamationmark.triangle.fill"
        default:
            "doc"
        }
    }

    private var iconColor: Color {
        switch item.status {
        case .success:
            .green
        case .failed:
            .red
        default:
            .secondary
        }
    }

    private func openInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([item.originalFileURL])
    }

    private func openOnVirusTotal() {
        NSWorkspace.shared.open(
            URL(string: "https://www.virustotal.com/gui/file/\(item.sha256)") ?? URL(string: "https://virustotal.com")!
        )
    }
}

private extension DownloadMonitorFileCategory {
    var localizedTitle: String {
        switch self {
        case .documents:
            localizedString("downloadsmonitor.filetype.documents")
        case .archives:
            localizedString("downloadsmonitor.filetype.archives")
        case .images:
            localizedString("downloadsmonitor.filetype.images")
        case .audio:
            localizedString("downloadsmonitor.filetype.audio")
        case .video:
            localizedString("downloadsmonitor.filetype.video")
        case .applications:
            localizedString("downloadsmonitor.filetype.applications")
        case .other:
            localizedString("downloadsmonitor.filetype.other")
        }
    }

    var extensionExamples: String {
        switch self {
        case .archives:
            ".zip, .rar, .7z, .tar, .gz"
        case .applications:
            ".app, .dmg, .pkg, .ipa"
        case .documents:
            ".pdf, .txt, .rtf, .docx, .json"
        case .images:
            ".png, .jpg, .gif, .webp, .heic"
        case .audio:
            ".mp3, .m4a, .wav, .flac"
        case .video:
            ".mp4, .mov, .mkv, .avi"
        case .other:
            localizedString("downloadsmonitor.filetype.other.extensions")
        }
    }

    private func localizedString(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

#Preview {
    DownloadsMonitorView()
        .frame(minWidth: 600, minHeight: 500)
}

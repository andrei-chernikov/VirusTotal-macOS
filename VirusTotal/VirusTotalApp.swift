//
//  VirusTotalApp.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-19.
//

import SwiftUI
import Defaults
import TipKit
import Sparkle

@main
struct VirusTotalApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openURL) private var openURL
    @Default(.appFirstLaunch) private var appFirstLaunch: Bool
    @State private var shouldShowFullMainWindowAfterRelaunch = Defaults[.showMainWindowOnNextLaunch]
    @State private var scanHistoryManager = ScanHistoryManager.shared
    @State private var downloadsMonitor = DownloadsMonitorViewModel.shared
    private var appState = AppState.shared

    var body: some Scene {
        Window("VirusTotal for macOS", id: WindowID.main.rawValue) {
            mainWindowContent
                .task(priority: .background) {
                    appDelegate.openMainWindowAction = {
                        openWindow(id: WindowID.main.rawValue)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .openMainWindowRequested)) { _ in
                    appDelegate.prepareForOpeningWindow()
                    openWindow(id: WindowID.main.rawValue)
                }
                .onReceive(NotificationCenter.default.publisher(for: .openSettingsRequested)) { _ in
                    appDelegate.prepareForOpeningWindow()
                    openSettings()
                }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 800, height: 550)
        .defaultPosition(.center)
        .commandsRemoved()

        Window("About VirusTotal", id: WindowID.about.rawValue) {
            AboutView()
        }
        .defaultSize(width: 530, height: 220)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)

        Settings {
            SettingsView(updater: updaterController.updater)
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                openAboutWindow
            }
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
            CommandGroup(replacing: .newItem) {
                openMainWindow
            }
            CommandGroup(before: .help) {
                provideFeedback
                openLogDirectory
                Divider()
            }
            CommandGroup(before: .textEditing) {
                openSidebarSearch
            }
            CommandMenu("menubar.go.title") {
                menubarGo
            }
        }
    }

    @ViewBuilder
    private var mainWindowContent: some View {
        if AppRuntime.isRunningTests {
            EmptyView()
        } else if miniMode {
            MiniModeView()
                .frame(width: 290, height: 180)
        } else {
            ContentView()
                .sheet(isPresented: $appFirstLaunch, onDismiss: {
                    appFirstLaunch = false
                }, content: {
                    LaunchView()
                        .frame(width: 400, height: 430)
                })
                .task(priority: .background) {
                    do {
                        try await scanHistoryManager.load()
                    } catch {
                        log.error("Error loading scan entries: \(error)")
                    }
                    await NotificationManager.requestAuthorization()
                    downloadsMonitor.startIfNeeded()
                }
        }
    }

    // MARK: Menubar Items
    @ViewBuilder
    var openMainWindow: some View {
        Button {
            appDelegate.prepareForOpeningWindow()
            openWindow(id: WindowID.main.rawValue)
        } label: {
            Text("menubar.open.main")
        }
        .keyboardShortcut("n", modifiers: .command)
    }

    @ViewBuilder
    var openAboutWindow: some View {
        Button {openWindow(id: "about")} label: {
            Text("menubar.open.about")
        }
    }

    @ViewBuilder
    var openSidebarSearch: some View {
        Button {appState.sidebarSearchFocused = true} label: {
            Text("menubar.edit.search")
        }
        .keyboardShortcut("f")
    }

    @ViewBuilder
    var openLogDirectory: some View {
        Button {
            logDirectory.openInFinder()
        } label: {
            Text("menubar.check.log")
        }
    }

    @ViewBuilder
    var provideFeedback: some View {
        Button {
            openURL(feedbackURL)
        } label: {
            Text("menubar.help.feedback")
        }
    }

    @ViewBuilder
    var menubarGo: some View {
        Button {
            appState.selectedSidebarItem = .home
        } label: {
            Text("menubar.go.home")
        }
        .keyboardShortcut("1")
        .disabled(miniMode)

        Button {
            appState.selectedSidebarItem = .fileUpload
        } label: {
            Text("menubar.go.file")
        }
        .keyboardShortcut("2")
        .disabled(miniMode)

        Button {
            appState.selectedSidebarItem = .urlLookup
        } label: {
            Text("menubar.go.url")
        }
        .keyboardShortcut("3")
        .disabled(miniMode)

        Button {
            appState.selectedSidebarItem = .fileBatch
        } label: {
            Text("menubar.go.fileBatch")
        }
        .keyboardShortcut("4")
        .disabled(miniMode)
    }

    // MARK: Internal
    init() {
        if !AppRuntime.isRunningTests {
            APIKeychain.migrateAPIKeyFromDefaultsIfNeeded()
        }
        // Consumed once, so a relaunch triggered from Settings lands in the
        // full window and the next launch honours Mini Mode again.
        Defaults[.showMainWindowOnNextLaunch] = false
        // Tips
        #if DEBUG
        if !AppRuntime.isRunningTests { try? Tips.resetDatastore() }
        #endif
        if !AppRuntime.isRunningTests { try? Tips.configure() }
        // Updater
        updaterController = SPUStandardUpdaterController(
            startingUpdater: !AppRuntime.isRunningTests,
            updaterDelegate: nil,
            userDriverDelegate: nil)
        // Logging
        LogManager.configureLogging()
        appDelegate.shouldShowMainWindowOnLaunch = shouldShowFullMainWindowAfterRelaunch
    }

    // MARK: Private
    private let updaterController: SPUStandardUpdaterController
    private let feedbackURL = URL(string: "https://github.com/Jerry23011/VirusTotal-macOS/issues/new/choose")!
    private var miniMode: Bool { Defaults[.miniMode] && !shouldShowFullMainWindowAfterRelaunch && !appFirstLaunch }
    private var logDirectory: URL {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        return homeDirectory.appendingPathComponent("Library/Logs", isDirectory: true)
    }
}

/// Hosted tests must not start monitoring the user's folder, migrate their
/// API key, show onboarding or contact the updater during an automated run.
enum AppRuntime {
    static var isRunningTests: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestBundlePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }
}

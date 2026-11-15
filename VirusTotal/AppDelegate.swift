//
//  AppDelegate.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-26.
//

import Cocoa
import Defaults
import SwiftUI
import UserNotifications

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var openMainWindowAction: (() -> Void)?
    var shouldShowMainWindowOnLaunch = false
    let menuPanelRouter = MenuPanelRouter()
    var menuPanelContent: (() -> AnyView)?
    private var menuPanel: NSPopover?
    var isMenuPanelPrepared: Bool { menuPanel != nil }

    private(set) var statusItem: NSStatusItem?
    private var statusMenu: NSMenu?
    private var fallbackMainWindow: NSWindow?
    private var didHideInitialBackgroundWindow = false
    private let notificationDelegate = NotificationCenterDelegate()

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !AppRuntime.isRunningTests else { return }
        NSApp.servicesProvider = ServiceProvider()
        applyPresentationMode()
        observeMenuBarModeChanges()
        observePanelModalChanges()
        UNUserNotificationCenter.current().delegate = notificationDelegate
        DownloadsMonitorViewModel.shared.startIfNeeded()
    }

    func applicationDidUpdate(_ notification: Notification) {
        guard let mainWindow = NSApp.findWindow(WindowID.main) else { return }
        mainWindow.delegate = self

        if shouldHideInitialWindow(requiresSetup: Defaults[.appFirstLaunch]), !didHideInitialBackgroundWindow {
            didHideInitialBackgroundWindow = true
            mainWindow.orderOut(nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            if Defaults[.menuBarOnly] { showMenuPanel() } else { showMainWindow() }
        }
        return true
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard Defaults[.menuBarOnly], sender.identifier?.rawValue == WindowID.main.rawValue else {
            return true
        }

        sender.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
        return false
    }

    private func observeMenuBarModeChanges() {
        NotificationCenter.default.addObserver(
            forName: .menuBarModeChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.applyPresentationMode()
            }
        }
    }

    private func observePanelModalChanges() {
        NotificationCenter.default.addObserver(
            forName: .menuPanelModalChanged, object: nil, queue: .main
        ) { [weak self] notification in
            let isPresented = notification.object as? Bool ?? false
            MainActor.assumeIsolated {
                self?.menuPanel?.behavior = isPresented ? .applicationDefined : .transient
            }
        }
    }

    func shouldHideInitialWindow(requiresSetup: Bool) -> Bool {
        Defaults[.menuBarOnly] && !requiresSetup
    }

    func applyPresentationMode() {
        if Defaults[.menuBarOnly] {
            configureStatusItem()
            NSApp.setActivationPolicy(.accessory)
            if menuPanelContent != nil {
                NSApp.windows.filter { $0.isVisible && $0 != statusItem?.button?.window }.forEach { $0.orderOut(nil) }
                showMenuPanel()
            }
        } else {
            menuPanel?.close()
            NSApp.setActivationPolicy(.regular)
            removeStatusItem()
            if menuPanelContent != nil { showMainWindow() }
            didHideInitialBackgroundWindow = false
        }
    }

    private func configureStatusItem() {
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            let image = NSImage(named: "MenuBarIcon") ?? NSImage(systemSymbolName: "shield.lefthalf.filled", accessibilityDescription: "VirusTotal")
            image?.size = NSSize(width: 18, height: 18)
            image?.isTemplate = true
            statusItem?.button?.image = image
            statusItem?.button?.imagePosition = .imageOnly
            statusItem?.button?.target = self
            statusItem?.button?.action = #selector(handleStatusItemClick(_:))
            statusItem?.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
            statusItem?.button?.setAccessibilityLabel("VirusTotal")
        }
        statusItem?.button?.toolTip = localizedString("menubar.status.help")

        let menu = NSMenu()
        menu.addItem(statusMenuItem(
            title: localizedString("menubar.open.main"),
            action: #selector(openMainWindowFromMenu)
        ))
        menu.addItem(statusMenuItem(
            title: localizedString("menubar.open.settings"),
            action: #selector(openSettingsFromMenu),
            keyEquivalent: ","
        ))
        menu.addItem(.separator())
        menu.addItem(statusMenuItem(
            title: localizedString("menubar.quit"),
            action: #selector(quitFromMenu),
            keyEquivalent: "q"
        ))
        statusMenu = menu
        statusItem?.menu = nil
    }

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showStatusMenu()
        } else {
            openMainWindowFromMenu()
        }
    }

    private func showStatusMenu() {
        guard let statusItem, let statusMenu else { return }
        statusItem.menu = statusMenu
        defer { statusItem.menu = nil }
        statusItem.button?.performClick(nil)
    }

    private func statusMenuItem(title: String, action: Selector, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    private func localizedString(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    private func removeStatusItem() {
        guard let statusItem else { return }
        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
        statusMenu = nil
    }

    @objc private func openMainWindowFromMenu() {
        if Defaults[.menuBarOnly] {
            if menuPanel?.isShown == true { menuPanel?.close() } else { showMenuPanel() }
        } else {
            showMainWindow()
        }
    }

    func showMenuPanel(settings: Bool = false) {
        guard let button = statusItem?.button, let menuPanelContent else { return }
        if settings { menuPanelRouter.showingSettings = true }
        if menuPanel == nil {
            let popover = NSPopover()
            popover.behavior = .transient
            popover.contentViewController = NSHostingController(rootView: menuPanelContent())
            menuPanel = popover
        }
        guard let menuPanel else { return }
        let visible = button.window?.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        menuPanel.contentSize = NSSize(width: min(420, max(300, visible.width - 24)),
                                       height: min(480, max(300, visible.height - 48)))
        if !menuPanel.isShown { menuPanel.show(relativeTo: button.bounds, of: button, preferredEdge: .minY) }
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openSettingsFromMenu() {
        if Defaults[.menuBarOnly] {
            showMenuPanel(settings: true)
        } else {
            prepareForOpeningWindow()
            NotificationCenter.default.post(name: .openSettingsRequested, object: nil)
        }
    }

    @objc private func quitFromMenu() {
        NSApp.terminate(nil)
    }

    private func showMainWindow() {
        didHideInitialBackgroundWindow = true
        prepareForOpeningWindow()
        if let openMainWindowAction {
            openMainWindowAction()
            if let window = NSApp.findWindow(WindowID.main) {
                bringWindowToFront(window)
            }
        } else {
            showExistingMainWindowOrFallback()
        }
    }

    private func showExistingMainWindowOrFallback() {
        if let mainWindow = NSApp.findWindow(WindowID.main) {
            mainWindow.delegate = self
            bringWindowToFront(mainWindow)
            return
        }

        if let fallbackMainWindow {
            bringWindowToFront(fallbackMainWindow)
            return
        }

        let isMiniMode = Defaults[.miniMode]
        let windowSize = isMiniMode ? NSSize(width: 290, height: 180) : NSSize(width: 808, height: 639)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.identifier = NSUserInterfaceItemIdentifier(WindowID.main.rawValue)
        window.delegate = self
        window.title = "VirusTotal for macOS"
        window.titleVisibility = isMiniMode ? .hidden : .visible
        window.titlebarAppearsTransparent = isMiniMode
        window.isReleasedWhenClosed = false
        window.isOpaque = true
        window.center()

        if isMiniMode {
            window.contentView = NSHostingView(
                rootView: AnyView(MiniModeView()
                    .frame(width: 290, height: 180))
            )
        } else {
            window.contentView = NSHostingView(
                rootView: AnyView(ContentView()
                    .frame(minWidth: 808, minHeight: 639))
            )
        }

        fallbackMainWindow = window
        bringWindowToFront(window)
    }

    private func bringWindowToFront(_ window: NSWindow) {
        prepareForOpeningWindow()

        if window.isMiniaturized {
            window.deminiaturize(nil)
        }

        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func prepareForOpeningWindow() {
        didHideInitialBackgroundWindow = true
        NSApp.setActivationPolicy(Defaults[.menuBarOnly] ? .accessory : .regular)
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

final class NotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        let isAppActive = await MainActor.run { NSApp.isActive }
        return isAppActive ? [] : [.banner, .list, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        guard userInfo["destination"] as? String == "downloadsMonitor" else { return }

        let filePath = userInfo["filePath"] as? String
        let sha256 = userInfo["sha256"] as? String

        await MainActor.run {
            var payload: [AnyHashable: Any] = [:]
            if let filePath { payload["filePath"] = filePath }
            if let sha256 { payload["sha256"] = sha256 }

            DownloadsMonitorViewModel.shared.handleNotificationSelection(filePath: filePath)
            NSApp.activate(ignoringOtherApps: true)
            AppState.shared.selectedSidebarItem = .downloadsMonitor
            NotificationCenter.default.post(name: .openMainWindowRequested, object: nil)
            NotificationCenter.default.post(
                name: .downloadsMonitorFileRequested,
                object: nil,
                userInfo: payload
            )
        }
    }
}

extension Notification.Name {
    static let menuPanelModalChanged = Notification.Name("menuPanelModalChanged")
    static let menuBarModeChanged = Notification.Name("menuBarModeChanged")
    static let openMainWindowRequested = Notification.Name("openMainWindowRequested")
    static let openSettingsRequested = Notification.Name("openSettingsRequested")
    static let downloadsMonitorFileRequested = Notification.Name("downloadsMonitorFileRequested")
}

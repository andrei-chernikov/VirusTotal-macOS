import AppKit
import Defaults
import Testing
import SwiftUI
@testable import VirusTotal

@MainActor
@Suite("Menu bar only mode", .serialized)
struct MenuBarModeTests {
    @Test("Menu bar mode keeps the Dock hidden when opening an interface and never enables folder scanning")
    func interfaceKeepsDockHidden() {
        withMode(true) { delegate in
            let monitoring = Defaults[.autoScanDownloadsEnabled]
            delegate.prepareForOpeningWindow()
            #expect(NSApp.activationPolicy() == .accessory)
            #expect(delegate.statusItem != nil)
            #expect(Defaults[.autoScanDownloadsEnabled] == monitoring)
        }
    }

    @Test("Closing the main window hides it while the application stays alive")
    func closingKeepsMenuBarRunning() {
        withMode(true) { delegate in
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.identifier = NSUserInterfaceItemIdentifier(WindowID.main.rawValue)
            defer { window.close() }
            window.orderFront(nil)
            #expect(!delegate.windowShouldClose(window))
            #expect(!window.isVisible)
            #expect(delegate.statusItem != nil)
            #expect(!delegate.applicationShouldTerminateAfterLastWindowClosed(NSApp))
        }
    }

    @Test("Disabling the mode restores the Dock and removes the status item immediately")
    func disablingRestoresNormalApplication() {
        withMode(true) { delegate in
            Defaults[.menuBarOnly] = false
            delegate.applyPresentationMode()
            #expect(NSApp.activationPolicy() == .regular)
            #expect(delegate.statusItem == nil)
        }
    }

    @Test("The primary status item click goes to an action instead of a pull-down menu")
    func primaryClickHasDirectAction() {
        withMode(true) { delegate in
            #expect(delegate.statusItem?.menu == nil)
            #expect(delegate.statusItem?.button?.action != nil)
            #expect(delegate.statusItem?.button?.target === delegate)
            delegate.menuPanelContent = { AnyView(Text("Test panel")) }
            let button = delegate.statusItem?.button
            if let action = button?.action {
                NSApp.sendAction(action, to: button?.target, from: button)
            }
            #expect(delegate.isMenuPanelPrepared)
            #expect(NSApp.activationPolicy() == .accessory)
        }
    }

    @Test("Settings requested on first opening selects settings before the panel appears")
    func settingsRouteIsSetBeforePresentation() {
        withMode(true) { delegate in
            delegate.menuPanelContent = { AnyView(Text("Test panel")) }
            delegate.showMenuPanel(settings: true)
            #expect(delegate.menuPanelRouter.showingSettings)
            #expect(delegate.isMenuPanelPrepared)
        }
    }

    @Test("Initial setup and restart requests use the menu panel")
    func setupIsNotHidden() {
        withMode(true) { delegate in
            #expect(delegate.shouldHideInitialWindow(requiresSetup: true))
            #expect(delegate.shouldHideInitialWindow(requiresSetup: false))
            delegate.shouldShowMainWindowOnLaunch = true
            #expect(delegate.shouldHideInitialWindow(requiresSetup: false))
        }
    }

    private func withMode(_ enabled: Bool, body: (AppDelegate) -> Void) {
        let original = Defaults[.menuBarOnly]
        let originalPolicy = NSApp.activationPolicy()
        let delegate = AppDelegate()
        defer {
            Defaults[.menuBarOnly] = false
            delegate.applyPresentationMode()
            Defaults[.menuBarOnly] = original
            NSApp.setActivationPolicy(originalPolicy)
        }
        Defaults[.menuBarOnly] = enabled
        delegate.applyPresentationMode()
        body(delegate)
    }
}

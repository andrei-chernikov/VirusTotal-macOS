//
//  WindowManager.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-30.
//

import SwiftUI
import Defaults
import AppKit

class WindowManager {
    @MainActor static func showURLWindow() {
        if Defaults[.menuBarOnly] {
            AppState.shared.selectedSidebarItem = .urlLookup
            NotificationCenter.default.post(name: .openMainWindowRequested, object: nil)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 530),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )

        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.isOpaque = true
        window.center()
        window.contentView = NSHostingView(rootView: URLView())
        window.makeKeyAndOrderFront(nil)
    }

    @MainActor static func showFileWindow() {
        if Defaults[.menuBarOnly] {
            AppState.shared.selectedSidebarItem = .fileUpload
            NotificationCenter.default.post(name: .openMainWindowRequested, object: nil)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 530),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )

        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.isOpaque = true
        window.center()
        window.contentView = NSHostingView(rootView: FileView())
        window.makeKeyAndOrderFront(nil)
    }
}

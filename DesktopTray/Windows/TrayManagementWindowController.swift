import AppKit
import SwiftUI

/// トレイ管理画面の NSWindow ラッパー（Fix H）。
@MainActor
final class TrayManagementWindowController {
    private var window: NSWindow?

    func show(
        trays: [TrayManagementRow],
        onRename: @escaping (UUID, String) -> Void,
        onDelete: @escaping (UUID) -> Void,
        onCreateTray: @escaping () -> Void
    ) {
        let rootView = TrayManagementView(
            trays: trays,
            onRename: onRename,
            onDelete: onDelete,
            onCreateTray: onCreateTray
        )

        if let window {
            window.contentView = NSHostingView(rootView: rootView)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 480),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = NSLocalizedString("tray.management.title", comment: "")
        window.contentView = NSHostingView(rootView: rootView)
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    func close() {
        window?.orderOut(nil)
    }
}

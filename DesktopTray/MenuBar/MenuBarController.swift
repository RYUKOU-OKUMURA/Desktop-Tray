import AppKit
import SwiftUI

/// メニューバー常駐アイコン（要件定義 §15.3 / アーキテクチャ v0.1 §3.2）。
/// Fix E でサイドレールを廃止したため、新規トレイ / すべて展開 / すべて収納 /
/// 表示切替 / 終了 の5導線をここに集約する。詳細メニューは Phase 4 以降。
@MainActor
final class MenuBarController {
    private var statusItem: NSStatusItem?
    private let onNewTray: () -> Void
    private let onExpandAll: () -> Void
    private let onCollapseAll: () -> Void
    private let onToggleVisibility: () -> Void
    private let onQuit: () -> Void

    init(
        onNewTray: @escaping () -> Void,
        onExpandAll: @escaping () -> Void,
        onCollapseAll: @escaping () -> Void,
        onToggleVisibility: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.onNewTray = onNewTray
        self.onExpandAll = onExpandAll
        self.onCollapseAll = onCollapseAll
        self.onToggleVisibility = onToggleVisibility
        self.onQuit = onQuit
    }

    func show() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "tray.and.arrow.down",
            accessibilityDescription: "Desktop Tray"
        )
        item.button?.image?.isTemplate = true

        let menu = NSMenu()
        menu.addItem(makeItem(title: NSLocalizedString("tray.new", comment: ""), action: #selector(handleNewTray)))
        menu.addItem(.separator())
        menu.addItem(makeItem(title: NSLocalizedString("siderail.expandAll", comment: ""), action: #selector(handleExpandAll)))
        menu.addItem(makeItem(title: NSLocalizedString("siderail.collapseAll", comment: ""), action: #selector(handleCollapseAll)))
        menu.addItem(.separator())
        menu.addItem(makeItem(title: NSLocalizedString("menubar.toggleVisibility", comment: ""), action: #selector(handleToggle)))
        menu.addItem(.separator())
        menu.addItem(makeItem(title: NSLocalizedString("menubar.quit", comment: ""), action: #selector(handleQuit), isDestructive: true))
        item.menu = menu
        statusItem = item
    }

    func hide() {
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
    }

    private func makeItem(title: String, action: Selector, isDestructive: Bool = false) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        if isDestructive {
            item.attributedTitle = NSAttributedString(
                string: title,
                attributes: [.foregroundColor: NSColor.systemRed]
            )
        }
        return item
    }

    @objc private func handleNewTray() { onNewTray() }
    @objc private func handleExpandAll() { onExpandAll() }
    @objc private func handleCollapseAll() { onCollapseAll() }
    @objc private func handleToggle() { onToggleVisibility() }
    @objc private func handleQuit() { onQuit() }
}

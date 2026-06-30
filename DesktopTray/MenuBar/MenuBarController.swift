import AppKit

/// メニューバー常駐アイコン（任意・最小補助）（要件定義 §15.3 / アーキテクチャ v0.1 §3.2）。
/// MVP では「表示/非表示」「終了」のみ。詳細メニューは Phase 4 以降。
@MainActor
final class MenuBarController {
    private var statusItem: NSStatusItem?
    private var onToggleVisibility: (() -> Void)?
    private var onQuit: (() -> Void)?

    init(
        onToggleVisibility: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
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
        menu.addItem(makeItem(title: NSLocalizedString("menubar.toggleVisibility", comment: ""), action: #selector(handleToggle)))
        menu.addItem(.separator())
        menu.addItem(makeItem(title: NSLocalizedString("menubar.quit", comment: ""), action: #selector(handleQuit), isDestructive: true))
        menu.items.forEach { $0.target = self }
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

    @objc private func handleToggle() {
        onToggleVisibility?()
    }

    @objc private func handleQuit() {
        onQuit?()
    }
}

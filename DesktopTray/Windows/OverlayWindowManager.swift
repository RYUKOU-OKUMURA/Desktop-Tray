import AppKit
import SwiftUI

/// 全トレイのライフサイクル、Z-order、画面外補正を管理する（アーキテクチャ v0.1 §3.2 / §10）。
/// 外部ディスプレイ切断時は `clampToVisibleFrames()` で frame を可視領域内へ戻す。
@MainActor
final class OverlayWindowManager {
    private let layoutEngine: LayoutEngine
    private var controllers: [UUID: TrayWindowController] = [:]

    /// 内容生成を遅延評価するコンテンツプロバイダ。
    /// AppCoordinator / TrayListViewModel が差し替える。
    var contentProvider: ((UUID) -> AnyView)?

    init(layoutEngine: LayoutEngine = LayoutEngine()) {
        self.layoutEngine = layoutEngine
    }

    /// 保存状態から全トレイウィンドウを復元する（アーキテクチャ v0.1 §4.1）。
    func restoreWindows(from trays: [Tray]) {
        // 一度全て破棄
        controllers.values.forEach { $0.close() }
        controllers.removeAll()

        let visible = LayoutEngine.combinedVisibleFrame()

        for tray in trays {
            let controller = TrayWindowController(trayID: tray.id, layoutEngine: layoutEngine)
            let content = contentProvider?(tray.id) ?? AnyView(EmptyView())

            if tray.isCollapsed {
                // 収納タブのみ表示（タブ UI は SideRailController 側で扱う）
                let tabFrame = layoutEngine.collapsedTabFrame(index: tray.tabIndex, screen: visible)
                controller.show(content: { content }, frame: tabFrame)
                controller.hide()
            } else {
                let expanded = layoutEngine.expandedFrame(saved: tray.frame.cgRect, screen: visible)
                controller.show(content: { content }, frame: expanded)
            }
            controllers[tray.id] = controller
        }
    }

    /// 新規トレイを表示する。
    func addTray(_ tray: Tray) {
        guard controllers[tray.id] == nil else { return }
        let controller = TrayWindowController(trayID: tray.id, layoutEngine: layoutEngine)
        let content = contentProvider?(tray.id) ?? AnyView(EmptyView())
        let visible = LayoutEngine.combinedVisibleFrame()
        let frame = layoutEngine.expandedFrame(saved: tray.frame.cgRect, screen: visible)
        controller.show(content: { content }, frame: frame)
        controllers[tray.id] = controller
    }

    /// トレイを破棄する。
    func removeTray(id: UUID) {
        controllers[id]?.close()
        controllers.removeValue(forKey: id)
    }

    /// 指定トレイのコンテンツを差し替える（アイテム更新時など）。
    func updateContent(for id: UUID) {
        guard let controller = controllers[id], let provider = contentProvider else { return }
        let content = provider(id)
        if let hosting = controller.panel?.contentView as? NSHostingView<AnyView> {
            hosting.rootView = content
        } else {
            controller.panel?.contentView = NSHostingView(rootView: content)
        }
    }

    /// 指定トレイを収納する。
    func collapse(tray: Tray) {
        guard let controller = controllers[tray.id] else { return }
        let visible = LayoutEngine.combinedVisibleFrame()
        let tabFrame = layoutEngine.collapsedTabFrame(index: tray.tabIndex, screen: visible)
        controller.collapse(to: tabFrame)
    }

    /// 指定トレイを展開する。
    func expand(tray: Tray) {
        guard let controller = controllers[tray.id] else { return }
        let visible = LayoutEngine.combinedVisibleFrame()
        let expanded = layoutEngine.expandedFrame(saved: tray.frame.cgRect, screen: visible)
        let tabFrame = layoutEngine.collapsedTabFrame(index: tray.tabIndex, screen: visible)
        controller.expand(to: expanded, from: tabFrame)
    }

    /// 画面構成変更時に全トレイを可視領域へ clamp する。
    func clampAllToVisibleFrames() {
        let controllersCopy = controllers
        for (_, controller) in controllersCopy {
            guard let panel = controller.panel, panel.isVisible else { continue }
            let clamped = layoutEngine.clampToVisibleFrames(panel.frame)
            if clamped != panel.frame {
                panel.setFrame(clamped, display: true, animate: true)
            }
        }
    }

    /// 全トレイを展開状態へ。
    func expandAll(trays: [Tray]) {
        for tray in trays where tray.isCollapsed {
            expand(tray: tray)
        }
    }

    /// 全トレイを収納状態へ。
    func collapseAll(trays: [Tray]) {
        for tray in trays where !tray.isCollapsed {
            collapse(tray: tray)
        }
    }

    /// 全パネルを破棄する（アプリ終了時）。
    func tearDown() {
        controllers.values.forEach { $0.close() }
        controllers.removeAll()
    }
}

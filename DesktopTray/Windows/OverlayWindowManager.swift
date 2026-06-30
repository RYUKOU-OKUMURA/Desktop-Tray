import AppKit
import SwiftUI

/// 全トレイのライフサイクル、Z-order、画面外補正を管理する（アーキテクチャ v0.1 §3.2 / §10）。
/// 外部ディスプレイ切断時は `clampToVisibleFrames()` で frame を可視領域内へ戻す。
///
/// 収納仕様（Fix D）: `orderOut` せず左端画面外へスライドし、パネル自体をタブ化する。
@MainActor
final class OverlayWindowManager {
    private let layoutEngine: LayoutEngine
    private var controllers: [UUID: TrayWindowController] = [:]

    /// 内容生成を遅延評価するコンテンツプロバイダ。
    /// AppCoordinator / TrayListViewModel が差し替える。
    var contentProvider: ((UUID) -> AnyView)?

    /// 収納タブとして覗かせる幅。
    var collapsedTabWidth: CGFloat { layoutEngine.collapsedTabWidth }

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
                // 収納状態: 左端画面外へスライドした frame で表示（orderOut しない）
                let expandedSaved = layoutEngine.expandedFrame(saved: tray.frame.cgRect, screen: visible)
                let collapsedFrame = layoutEngine.collapsedEdgeFrame(
                    saved: expandedSaved,
                    tabWidth: layoutEngine.collapsedTabWidth
                )
                controller.show(content: { content }, frame: collapsedFrame)
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
    /// ガラス背景（NSVisualEffectView）は維持したまま SwiftUI のみ更新。
    func updateContent(for id: UUID) {
        guard let controller = controllers[id], let provider = contentProvider else { return }
        controller.updateContentView(provider(id))
    }

    /// 指定トレイを左端画面外へスライド収納する（Fix D）。
    func collapseToEdge(trayID: UUID, savedFrame: CGRect) {
        guard let controller = controllers[trayID] else { return }
        controller.collapseToEdge(savedFrame: savedFrame, tabWidth: layoutEngine.collapsedTabWidth)
    }

    /// 指定トレイを保存 frame へスライド展開する（Fix D）。
    func expandFromEdge(trayID: UUID, savedFrame: CGRect) {
        guard let controller = controllers[trayID] else { return }
        let visible = LayoutEngine.combinedVisibleFrame()
        let expanded = layoutEngine.expandedFrame(saved: savedFrame, screen: visible)
        controller.expandFromEdge(savedFrame: expanded)
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
        let visible = LayoutEngine.combinedVisibleFrame()
        for tray in trays where tray.isCollapsed {
            let expanded = layoutEngine.expandedFrame(saved: tray.frame.cgRect, screen: visible)
            expandFromEdge(trayID: tray.id, savedFrame: expanded)
        }
    }

    /// 全トレイを収納状態へ。
    func collapseAll(trays: [Tray]) {
        let visible = LayoutEngine.combinedVisibleFrame()
        for tray in trays where !tray.isCollapsed {
            let expanded = layoutEngine.expandedFrame(saved: tray.frame.cgRect, screen: visible)
            collapseToEdge(trayID: tray.id, savedFrame: expanded)
        }
    }

    /// 全パネルを破棄する（アプリ終了時）。
    func tearDown() {
        controllers.values.forEach { $0.close() }
        controllers.removeAll()
    }
}

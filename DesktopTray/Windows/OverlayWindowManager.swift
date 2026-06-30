import AppKit
import SwiftUI

/// 全トレイのライフサイクル、Z-order、画面外補正を管理する（アーキテクチャ v0.1 §3.2 / §10）。
/// Fix G: 収納時は TrayPanel を `orderOut` し、TabRail がタブ UI を担う。
@MainActor
final class OverlayWindowManager {
    private let layoutEngine: LayoutEngine
    private var controllers: [UUID: TrayWindowController] = [:]

    var contentProvider: ((UUID) -> AnyView)?

    init(layoutEngine: LayoutEngine = LayoutEngine()) {
        self.layoutEngine = layoutEngine
    }

    /// 保存状態から全トレイウィンドウを復元する。
    func restoreWindows(from trays: [Tray]) {
        controllers.values.forEach { $0.close() }
        controllers.removeAll()

        let visible = LayoutEngine.combinedVisibleFrame()

        for tray in trays {
            let controller = TrayWindowController(trayID: tray.id, layoutEngine: layoutEngine)
            let content = contentProvider?(tray.id) ?? AnyView(EmptyView())
            let expanded = layoutEngine.expandedFrame(saved: tray.frame.cgRect, screen: visible)
            controller.show(content: { content }, frame: expanded)

            if tray.isCollapsed {
                controller.hide()
            }

            controllers[tray.id] = controller
        }
    }

    func addTray(_ tray: Tray) {
        guard controllers[tray.id] == nil else { return }
        let controller = TrayWindowController(trayID: tray.id, layoutEngine: layoutEngine)
        let content = contentProvider?(tray.id) ?? AnyView(EmptyView())
        let visible = LayoutEngine.combinedVisibleFrame()
        let frame = layoutEngine.expandedFrame(saved: tray.frame.cgRect, screen: visible)
        controller.show(content: { content }, frame: frame)
        controllers[tray.id] = controller
    }

    func removeTray(id: UUID) {
        controllers[id]?.close()
        controllers.removeValue(forKey: id)
    }

    func updateContent(for id: UUID) {
        guard let controller = controllers[id], let provider = contentProvider else { return }
        controller.updateContentView(provider(id))
    }

    /// 収納: パネルを非表示にする。
    func collapse(trayID: UUID) {
        controllers[trayID]?.hide()
    }

    /// 展開: 保存 frame でパネルを再表示する。
    func expand(trayID: UUID, savedFrame: CGRect) {
        guard let controller = controllers[trayID] else { return }
        let visible = LayoutEngine.combinedVisibleFrame()
        let expanded = layoutEngine.expandedFrame(saved: savedFrame, screen: visible)
        controller.updateFrame(expanded, animate: false)
        controller.unhide()
    }

    func ensureController(for tray: Tray) {
        if controllers[tray.id] == nil {
            addTray(tray)
        }
    }

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

    func expandAll(trays: [Tray]) {
        let visible = LayoutEngine.combinedVisibleFrame()
        for tray in trays where tray.isCollapsed {
            let expanded = layoutEngine.expandedFrame(saved: tray.frame.cgRect, screen: visible)
            expand(trayID: tray.id, savedFrame: expanded)
        }
    }

    func collapseAll(trays: [Tray]) {
        for tray in trays where !tray.isCollapsed {
            collapse(trayID: tray.id)
        }
    }

    func tearDown() {
        controllers.values.forEach { $0.close() }
        controllers.removeAll()
    }
}

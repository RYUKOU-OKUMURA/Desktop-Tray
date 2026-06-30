import AppKit
import SwiftUI

/// Phase 1 用のプロトタイプ起動コーディネータ。
/// モックデータで「気持ちいいトレイ」と左レールを動かす（Phase 1 完了条件）。
/// Phase 2 で `AppCoordinator`（実ファイル連携版）へ差し替える。
@MainActor
final class PrototypeCoordinator {
    private let overlayManager: OverlayWindowManager
    private let sideRailController: SideRailController
    private let dragBridge: DragSessionBridge

    @Observable
    final class State {
        var trays: [Tray]
        var snapGuideFrame: CGRect?

        init(trays: [Tray]) {
            self.trays = trays
        }
    }

    private let state: State

    init() {
        let layout = LayoutEngine()
        self.overlayManager = OverlayWindowManager(layoutEngine: layout)
        self.sideRailController = SideRailController(layoutEngine: layout)
        self.dragBridge = DragSessionBridge(layoutEngine: layout)
        self.state = State(trays: MockTrayData.allTrays)
    }

    func start() {
        // コンテンツプロバイダを設定
        overlayManager.contentProvider = { [weak self] trayID in
            guard let self else { return AnyView(EmptyView()) }
            return self.makeTrayContent(for: trayID)
        }
        sideRailController.contentProvider = { [weak self] in
            guard let self else { return AnyView(EmptyView()) }
            return AnyView(self.makeSideRailContent())
        }

        // ウィンドウ復元（モック）
        overlayManager.restoreWindows(from: state.trays)
        sideRailController.show()

        // 画面構成変更を監視して clamp
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func stop() {
        NSWorkspace.shared.notificationCenter.removeObserver(
            self,
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        overlayManager.tearDown()
        sideRailController.close()
    }

    // MARK: - Content builders

    private func makeTrayContent(for trayID: UUID) -> AnyView {
        guard let tray = state.trays.first(where: { $0.id == trayID }) else {
            return AnyView(EmptyView())
        }
        let presentations = MockTrayData.samplePresentations
        return AnyView(
            TrayPanelView(
                tray: tray,
                items: presentations,
                iconProvider: { _ in nil },
                onItemDoubleClick: { _ in
                    NSSound.beep()
                },
                onItemReveal: { _ in
                    NSSound.beep()
                },
                onItemUnassign: { _ in
                    NSSound.beep()
                },
                onCollapse: { [weak self] in
                    self?.collapseTray(id: trayID)
                },
                toastMessage: .constant(nil)
            )
        )
    }

    private func makeSideRailContent() -> some View {
        SideRailView(
            collapsedTrays: state.trays.filter(\.isCollapsed),
            onNewTray: { [weak self] in self?.addNewTray() },
            onTabTap: { [weak self] tray in self?.expandTray(id: tray.id) },
            onExpandAll: { [weak self] in self?.expandAll() },
            onCollapseAll: { [weak self] in self?.collapseAll() },
            onQuit: { NSApp.terminate(nil) }
        )
    }

    // MARK: - Actions

    private func addNewTray() {
        let color = TrayTheme.palette[state.trays.count % TrayTheme.palette.count]
        let new = Tray(
            name: "新規トレイ",
            type: .manual,
            color: color,
            frame: TrayFrame(x: 200, y: 200, width: 400, height: 300)
        )
        state.trays.append(new)
        overlayManager.addTray(new)
        sideRailController.refresh()
    }

    private func collapseTray(id: UUID) {
        guard let idx = state.trays.firstIndex(where: { $0.id == id }) else { return }
        state.trays[idx].isCollapsed = true
        state.trays[idx].tabIndex = state.trays.filter(\.isCollapsed).count - 1
        overlayManager.collapse(tray: state.trays[idx])
        sideRailController.refresh()
    }

    private func expandTray(id: UUID) {
        guard let idx = state.trays.firstIndex(where: { $0.id == id }) else { return }
        state.trays[idx].isCollapsed = false
        overlayManager.expand(tray: state.trays[idx])
        sideRailController.refresh()
    }

    private func expandAll() {
        for idx in state.trays.indices where state.trays[idx].isCollapsed {
            state.trays[idx].isCollapsed = false
        }
        overlayManager.expandAll(trays: state.trays)
        sideRailController.refresh()
    }

    private func collapseAll() {
        var tabIdx = 0
        for idx in state.trays.indices where !state.trays[idx].isCollapsed {
            state.trays[idx].isCollapsed = true
            state.trays[idx].tabIndex = tabIdx
            tabIdx += 1
        }
        overlayManager.collapseAll(trays: state.trays)
        sideRailController.refresh()
    }

    @objc private func screensChanged() {
        overlayManager.clampAllToVisibleFrames()
        sideRailController.repositionIfNeeded()
    }
}

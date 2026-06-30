import AppKit
import SwiftUI

/// 起動 orchestration を担うアプリコーディネータ（アーキテクチャ v0.1 §3.3 / §4.1）。
/// `PersistenceStore.load → DesktopScanner.scanDesktop → SmartTrayEvaluator.evaluate →
///  OverlayWindowManager.restoreWindows → FileSystemWatcher.start` を実行し、
/// 起動 1 秒以内に UI 表示を目指す（要件定義 §13.1）。
@MainActor
final class AppCoordinator {
    private let persistence: PersistenceStore
    private let scanner: DesktopScanner
    private let watcher: FileSystemWatcher
    private let evaluator: SmartTrayEvaluator
    private let engine: TrayEngine
    private let listViewModel: TrayListViewModel
    private let overlayManager: OverlayWindowManager
    private let sideRailController: SideRailController
    private var menuBarController: MenuBarController?
    private let layoutEngine: LayoutEngine

    private var panelViewModels: [UUID: TrayPanelViewModel] = [:]
    private var snapshot: PersistenceStore.Snapshot
    private var isStarted: Bool = false

    init() {
        let layout = LayoutEngine()
        self.layoutEngine = layout
        self.persistence = PersistenceStore()
        self.scanner = DesktopScanner()
        self.watcher = FileSystemWatcher()
        self.evaluator = SmartTrayEvaluator()
        self.engine = TrayEngine()
        self.listViewModel = TrayListViewModel(engine: engine, evaluator: evaluator)
        self.overlayManager = OverlayWindowManager(layoutEngine: layout)
        self.sideRailController = SideRailController(layoutEngine: layout)
        self.snapshot = PersistenceStore.Snapshot(
            schemaVersion: PersistenceStore.currentSchemaVersion,
            trays: [],
            displayMode: .mvpDefault
        )
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true

        // 1. 永続化ロード
        snapshot = persistence.loadSync()

        // 2. デスクトップスキャン
        let items = scanner.scanDesktop()
        listViewModel.setTrays(snapshot.trays)
        listViewModel.updateDesktopItems(items)

        // 3. stale マーク
        let snapshotWithStale = persistence.markStaleItems(
            in: snapshot,
            existingURLs: listViewModel.existingURLs
        )
        snapshot = snapshotWithStale
        listViewModel.setTrays(snapshot.trays)

        // 4. コンテンツプロバイダ設定
        overlayManager.contentProvider = { [weak self] trayID in
            self?.makeTrayContent(for: trayID) ?? AnyView(EmptyView())
        }
        sideRailController.contentProvider = { [weak self] in
            self?.makeSideRailContent() ?? AnyView(EmptyView())
        }

        // 5. ウィンドウ復元
        overlayManager.restoreWindows(from: listViewModel.trays)
        sideRailController.show()

        // 6. FSEvents 開始
        watcher.onChange = { [weak self] in
            Task { @MainActor in
                self?.handleDesktopChanged()
            }
        }
        watcher.start()

        // 7. メニューバー（任意）
        menuBarController = MenuBarController(
            onToggleVisibility: { [weak self] in self?.toggleVisibility() },
            onQuit: { NSApp.terminate(nil) }
        )
        menuBarController?.show()

        // 画面構成変更を監視
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func stop() {
        watcher.stop()
        overlayManager.tearDown()
        sideRailController.close()
        menuBarController?.hide()
        menuBarController = nil
        NSWorkspace.shared.notificationCenter.removeObserver(
            self,
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        // 終了時にスナップショット保存
        snapshot.trays = listViewModel.trays
        try? persistence.saveSync(snapshot)
        isStarted = false
    }

    // MARK: - Content builders

    private func makeTrayContent(for trayID: UUID) -> AnyView {
        guard let tray = listViewModel.trays.first(where: { $0.id == trayID }) else {
            return AnyView(EmptyView())
        }
        let vm = panelViewModels[trayID] ?? TrayPanelViewModel(trayID: trayID)
        panelViewModels[trayID] = vm
        let items = listViewModel.items(for: tray)
        vm.update(from: tray, smartItems: items, existingURLs: listViewModel.existingURLs)

        return AnyView(
            TrayPanelContainer(
                tray: tray,
                viewModel: vm,
                sourceItems: items,
                onCollapse: { [weak self] in
                    self?.collapseTray(id: trayID)
                },
                onUnassign: { [weak self] presentation in
                    self?.unassignItem(presentation: presentation, from: trayID)
                },
                onFileDrop: { [weak self] urls in
                    self?.handleFileDrop(urls: urls, into: trayID)
                }
            )
        )
    }

    private func makeSideRailContent() -> AnyView {
        AnyView(
            SideRailView(
                collapsedTrays: listViewModel.collapsedTrays,
                onNewTray: { [weak self] in self?.createNewTray() },
                onTabTap: { [weak self] tray in self?.expandTray(id: tray.id) },
                onExpandAll: { [weak self] in self?.expandAll() },
                onCollapseAll: { [weak self] in self?.collapseAll() },
                onQuit: { NSApp.terminate(nil) }
            )
        )
    }

    // MARK: - Actions

    private func createNewTray() {
        let tray = listViewModel.createTray(name: "新規トレイ")
        overlayManager.addTray(tray)
        sideRailController.refresh()
        saveSnapshot()
    }

    private func collapseTray(id: UUID) {
        guard let idx = listViewModel.trays.firstIndex(where: { $0.id == id }) else { return }
        listViewModel.trays[idx].isCollapsed = true
        engine.reindexCollapsedTabs(in: &listViewModel.trays)
        overlayManager.collapse(tray: listViewModel.trays[idx])
        sideRailController.refresh()
        saveSnapshot()
    }

    private func expandTray(id: UUID) {
        guard let idx = listViewModel.trays.firstIndex(where: { $0.id == id }) else { return }
        listViewModel.trays[idx].isCollapsed = false
        engine.reindexCollapsedTabs(in: &listViewModel.trays)
        overlayManager.expand(tray: listViewModel.trays[idx])
        sideRailController.refresh()
        saveSnapshot()
    }

    private func expandAll() {
        listViewModel.expandAll()
        overlayManager.expandAll(trays: listViewModel.trays)
        sideRailController.refresh()
        saveSnapshot()
    }

    private func collapseAll() {
        listViewModel.collapseAll()
        overlayManager.collapseAll(trays: listViewModel.trays)
        sideRailController.refresh()
        saveSnapshot()
    }

    private func handleFileDrop(urls: [URL], into trayID: UUID) {
        for url in urls {
            listViewModel.assign(url: url, to: trayID)
        }
        // 手動 membership 変更に伴いスマートトレイ（特に未分類）を再評価
        listViewModel.reevaluateSmart()
        refreshAllPanels()

        if let tray = listViewModel.trays.first(where: { $0.id == trayID }) {
            let message = String(
                format: NSLocalizedString("toast.added", comment: ""),
                tray.name
            )
            panelViewModels[trayID]?.showToast(message)
        }
        saveSnapshot()
    }

    private func unassignItem(presentation: TrayItemPresentation, from trayID: UUID) {
        guard let tray = listViewModel.trays.first(where: { $0.id == trayID }),
              let item = listViewModel.items(for: tray).first(where: { $0.id == presentation.id })
        else { return }
        listViewModel.unassign(url: item.url, from: trayID)
        listViewModel.reevaluateSmart()
        refreshAllPanels()

        let message = String(
            format: NSLocalizedString("toast.removed", comment: ""),
            tray.name
        )
        panelViewModels[trayID]?.showToast(message)
        saveSnapshot()
    }

    /// 全パネルのコンテンツを再描画する（スマート評価結果の伝搬用）。
    private func refreshAllPanels() {
        for tray in listViewModel.trays {
            overlayManager.updateContent(for: tray.id)
        }
        sideRailController.refresh()
    }

    private func handleDesktopChanged() {
        let items = scanner.scanDesktop()
        listViewModel.updateDesktopItems(items)
        // stale 更新
        snapshot.trays = listViewModel.trays
        snapshot = persistence.markStaleItems(
            in: snapshot,
            existingURLs: listViewModel.existingURLs
        )
        listViewModel.setTrays(snapshot.trays)
        // 全パネル更新
        for tray in listViewModel.trays {
            overlayManager.updateContent(for: tray.id)
        }
        sideRailController.refresh()
        saveSnapshot()
    }

    private func toggleVisibility() {
        // 簡易: 全パネル表示/非表示をトグル
        // Phase 4 でより粒度の細かい制御へ
        let anyVisible = listViewModel.expandedTrays.contains { _ in true }
        if anyVisible {
            overlayManager.collapseAll(trays: listViewModel.trays)
        } else {
            overlayManager.expandAll(trays: listViewModel.trays)
        }
    }

    private func saveSnapshot() {
        snapshot.trays = listViewModel.trays
        // 保存失敗時はメモリ状態を保持し次回再試行（アーキテクチャ v0.1 §5.3）
        try? persistence.saveSync(snapshot)
    }

    @objc private func screensChanged() {
        overlayManager.clampAllToVisibleFrames()
        sideRailController.repositionIfNeeded()
    }
}

import AppKit
import SwiftUI

/// 起動 orchestration を担うアプリコーディネータ（アーキテクチャ v0.1 §3.3 / §4.1）。
/// `PersistenceStore.load → DesktopScanner.scanDesktop → SmartTrayEvaluator.evaluate →
///  OverlayWindowManager.restoreWindows → FileSystemWatcher.start` を実行し、
/// 起動 1 秒以内に UI 表示を目指す（要件定義 §13.1）。
///
/// Fix D/E: サイドレールを廃止し、収納は左端画面外スライド（パネル自体がタブ）、
/// 新規トレイ/全展開/全収納/表示切替/終了 はメニューバーへ集約。
@MainActor
final class AppCoordinator {
    private let persistence: PersistenceStore
    private let scanner: DesktopScanner
    private let watcher: FileSystemWatcher
    private let evaluator: SmartTrayEvaluator
    private let engine: TrayEngine
    private let listViewModel: TrayListViewModel
    private let overlayManager: OverlayWindowManager
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

        // 5. ウィンドウ復元（収納状態のトレイは左端タブ化）
        overlayManager.restoreWindows(from: listViewModel.trays)

        // 6. FSEvents 開始
        watcher.onChange = { [weak self] in
            Task { @MainActor in
                self?.handleDesktopChanged()
            }
        }
        watcher.start()

        // 7. メニューバー（主操作導線）
        menuBarController = MenuBarController(
            onNewTray: { [weak self] in self?.createNewTray() },
            onExpandAll: { [weak self] in self?.expandAll() },
            onCollapseAll: { [weak self] in self?.collapseAll() },
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
                onExpand: { [weak self] in
                    self?.expandTray(id: trayID)
                },
                onUnassign: { [weak self] presentation in
                    self?.unassignItem(presentation: presentation, from: trayID)
                },
                onReorder: { [weak self] itemID, index in
                    self?.reorderItem(itemID: itemID, in: trayID, to: index)
                },
                onMoveFromOtherTray: { [weak self] itemID, fromTrayID in
                    self?.moveItem(itemID: itemID, from: fromTrayID, to: trayID)
                },
                onFileDrop: { [weak self] urls in
                    self?.handleFileDrop(urls: urls, into: trayID)
                }
            )
        )
    }

    // MARK: - Actions

    private func createNewTray() {
        let tray = listViewModel.createTray(name: "新規トレイ")
        overlayManager.addTray(tray)
        saveSnapshot()
    }

    private func collapseTray(id: UUID) {
        guard let idx = listViewModel.trays.firstIndex(where: { $0.id == id }) else { return }
        listViewModel.trays[idx].isCollapsed = true
        engine.reindexCollapsedTabs(in: &listViewModel.trays)
        let savedFrame = listViewModel.trays[idx].frame.cgRect
        overlayManager.collapseToEdge(trayID: id, savedFrame: savedFrame)
        // 収納後のコンテンツ（タブUI）へ差し替え
        overlayManager.updateContent(for: id)
        saveSnapshot()
    }

    private func expandTray(id: UUID) {
        guard let idx = listViewModel.trays.firstIndex(where: { $0.id == id }) else { return }
        listViewModel.trays[idx].isCollapsed = false
        engine.reindexCollapsedTabs(in: &listViewModel.trays)
        let savedFrame = listViewModel.trays[idx].frame.cgRect
        overlayManager.expandFromEdge(trayID: id, savedFrame: savedFrame)
        // 展開後のコンテンツ（通常UI）へ差し替え
        overlayManager.updateContent(for: id)
        saveSnapshot()
    }

    private func expandAll() {
        listViewModel.expandAll()
        overlayManager.expandAll(trays: listViewModel.trays)
        // 全パネルのコンテンツを展開状態へ差し替え
        refreshAllPanelContents()
        saveSnapshot()
    }

    private func collapseAll() {
        listViewModel.collapseAll()
        overlayManager.collapseAll(trays: listViewModel.trays)
        // 全パネルのコンテンツを収納タブUIへ差し替え
        refreshAllPanelContents()
        saveSnapshot()
    }

    private func handleFileDrop(urls: [URL], into trayID: UUID) {
        for url in urls {
            listViewModel.assign(url: url, to: trayID)
        }
        // 手動 membership 変更に伴いスマートトレイ（特に未分類）を再評価
        listViewModel.reevaluateSmart()
        refreshAllPanelContents()

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
        refreshAllPanelContents()

        let message = String(
            format: NSLocalizedString("toast.removed", comment: ""),
            tray.name
        )
        panelViewModels[trayID]?.showToast(message)
        saveSnapshot()
    }

    /// 同一トレイ内のアイテム並び替え（Fix F）。
    private func reorderItem(itemID: UUID, in trayID: UUID, to index: Int) {
        guard let tray = listViewModel.trays.first(where: { $0.id == trayID }),
              let item = listViewModel.items(for: tray).first(where: { $0.id == itemID })
        else { return }
        listViewModel.reorder(url: item.url, in: trayID, to: index)
        listViewModel.reevaluateSmart()
        refreshAllPanelContents()
        saveSnapshot()
    }

    /// 別トレイからアイテムを移動（Fix F）。
    private func moveItem(itemID: UUID, from fromTrayID: UUID, to toTrayID: UUID) {
        guard let fromTray = listViewModel.trays.first(where: { $0.id == fromTrayID }),
              let item = listViewModel.items(for: fromTray).first(where: { $0.id == itemID })
        else { return }
        listViewModel.move(url: item.url, from: fromTrayID, to: toTrayID)
        listViewModel.reevaluateSmart()
        refreshAllPanelContents()
        if let toTray = listViewModel.trays.first(where: { $0.id == toTrayID }) {
            let message = String(
                format: NSLocalizedString("toast.added", comment: ""),
                toTray.name
            )
            panelViewModels[toTrayID]?.showToast(message)
        }
        saveSnapshot()
    }

    /// 全パネルのコンテンツを再描画する（収納/展開切替 + スマート評価結果の伝搬用）。
    private func refreshAllPanelContents() {
        for tray in listViewModel.trays {
            overlayManager.updateContent(for: tray.id)
        }
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
        refreshAllPanelContents()
        saveSnapshot()
    }

    private func toggleVisibility() {
        // 全トレイが展開中なら全収納、そうでなければ全展開
        if listViewModel.expandedTrays.isEmpty {
            expandAll()
        } else {
            collapseAll()
        }
    }

    private func saveSnapshot() {
        snapshot.trays = listViewModel.trays
        // 保存失敗時はメモリ状態を保持し次回再試行（アーキテクチャ v0.1 §5.3）
        try? persistence.saveSync(snapshot)
    }

    @objc private func screensChanged() {
        overlayManager.clampAllToVisibleFrames()
    }
}

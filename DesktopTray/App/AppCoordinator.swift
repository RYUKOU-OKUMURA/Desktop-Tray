import AppKit
import SwiftUI

/// 起動 orchestration を担うアプリコーディネータ（アーキテクチャ v0.1 §3.3 / §4.1）。
/// Fix G: 収納時は TrayPanel を非表示にし TabRail でタブ管理。
/// Fix H: トレイ管理画面で名前変更・削除・新規作成を提供。
@MainActor
final class AppCoordinator {
    private let persistence: PersistenceStore
    private let scanner: DesktopScanner
    private let watcher: FileSystemWatcher
    private let evaluator: SmartTrayEvaluator
    private let engine: TrayEngine
    private let listViewModel: TrayListViewModel
    private let overlayManager: OverlayWindowManager
    private let tabRailController: TabRailController
    private let trayManagementController: TrayManagementWindowController
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
        self.tabRailController = TabRailController(layoutEngine: layout)
        self.trayManagementController = TrayManagementWindowController()
        self.snapshot = PersistenceStore.Snapshot(
            schemaVersion: PersistenceStore.currentSchemaVersion,
            trays: [],
            displayMode: .mvpDefault
        )
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true

        snapshot = persistence.loadSync()

        let items = scanner.scanDesktop()
        listViewModel.setTrays(snapshot.trays)
        listViewModel.updateDesktopItems(items)

        let snapshotWithStale = persistence.markStaleItems(
            in: snapshot,
            existingURLs: listViewModel.existingURLs
        )
        snapshot = snapshotWithStale
        listViewModel.setTrays(snapshot.trays)

        overlayManager.contentProvider = { [weak self] trayID in
            self?.makeTrayContent(for: trayID) ?? AnyView(EmptyView())
        }
        overlayManager.onTrayFrameChanged = { [weak self] trayID, frame in
            self?.handleTrayFrameChanged(trayID: trayID, frame: frame)
        }

        overlayManager.restoreWindows(from: listViewModel.trays)
        refreshTabRail()

        watcher.onChange = { [weak self] in
            Task { @MainActor in
                self?.handleDesktopChanged()
            }
        }
        watcher.start()

        menuBarController = MenuBarController(
            onNewTray: { [weak self] in self?.createNewTray() },
            onOpenTrayManagement: { [weak self] in self?.openTrayManagement() },
            onExpandAll: { [weak self] in self?.expandAll() },
            onCollapseAll: { [weak self] in self?.collapseAll() },
            onToggleVisibility: { [weak self] in self?.toggleVisibility() },
            onQuit: { NSApp.terminate(nil) }
        )
        menuBarController?.show()

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
        tabRailController.close()
        trayManagementController.close()
        menuBarController?.hide()
        menuBarController = nil
        NSWorkspace.shared.notificationCenter.removeObserver(
            self,
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
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

    // MARK: - TabRail

    private func refreshTabRail() {
        let collapsed = listViewModel.collapsedTrays
        let counts = Dictionary(uniqueKeysWithValues: listViewModel.trays.map { tray in
            (tray.id, listViewModel.items(for: tray).count)
        })

        if collapsed.isEmpty {
            tabRailController.hide()
            return
        }

        tabRailController.refresh(
            collapsedTrays: collapsed,
            itemCounts: counts,
            onExpand: { [weak self] id in
                self?.expandTray(id: id)
            },
            onNewTray: { [weak self] in
                self?.createNewTray()
            },
            onOpenSettings: { [weak self] in
                self?.openTrayManagement()
            }
        )
    }

    private func managementRows() -> [TrayManagementRow] {
        listViewModel.trays.map { tray in
            TrayManagementRow(
                id: tray.id,
                name: tray.name,
                color: tray.color,
                itemCount: listViewModel.items(for: tray).count,
                isSmart: tray.isSmart
            )
        }
    }

    // MARK: - Actions

    private func createNewTray() {
        let tray = listViewModel.createTray(name: "新規トレイ")
        overlayManager.addTray(tray)
        refreshTabRail()
        saveSnapshot()
    }

    private func collapseTray(id: UUID) {
        guard let idx = listViewModel.trays.firstIndex(where: { $0.id == id }) else { return }
        listViewModel.trays[idx].isCollapsed = true
        engine.reindexCollapsedTabs(in: &listViewModel.trays)
        overlayManager.collapse(trayID: id)
        refreshTabRail()
        saveSnapshot()
    }

    private func expandTray(id: UUID) {
        guard let idx = listViewModel.trays.firstIndex(where: { $0.id == id }) else { return }
        listViewModel.trays[idx].isCollapsed = false
        engine.reindexCollapsedTabs(in: &listViewModel.trays)
        let savedFrame = listViewModel.trays[idx].frame.cgRect
        overlayManager.expand(trayID: id, savedFrame: savedFrame)
        overlayManager.updateContent(for: id)
        refreshTabRail()
        saveSnapshot()
    }

    private func expandAll() {
        listViewModel.expandAll()
        overlayManager.expandAll(trays: listViewModel.trays)
        refreshAllPanelContents()
        refreshTabRail()
        saveSnapshot()
    }

    private func collapseAll() {
        listViewModel.collapseAll()
        overlayManager.collapseAll(trays: listViewModel.trays)
        refreshTabRail()
        saveSnapshot()
    }

    private func openTrayManagement() {
        trayManagementController.show(
            trays: managementRows(),
            onRename: { [weak self] id, name in
                self?.renameTray(id: id, name: name)
            },
            onDelete: { [weak self] id in
                self?.deleteTray(id: id)
            },
            onCreateTray: { [weak self] in
                self?.createNewTray()
            }
        )
    }

    private func renameTray(id: UUID, name: String) {
        listViewModel.renameTray(id: id, name: name)
        refreshAllPanelContents()
        refreshTabRail()
        saveSnapshot()
        openTrayManagement()
    }

    private func deleteTray(id: UUID) {
        listViewModel.deleteTray(id: id)
        overlayManager.removeTray(id: id)
        panelViewModels.removeValue(forKey: id)
        refreshTabRail()
        saveSnapshot()
        openTrayManagement()
    }

    private func handleFileDrop(urls: [URL], into trayID: UUID) {
        for url in urls {
            listViewModel.assign(url: url, to: trayID)
        }
        listViewModel.reevaluateSmart()
        refreshAllPanelContents()
        refreshTabRail()

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
        refreshTabRail()

        let message = String(
            format: NSLocalizedString("toast.removed", comment: ""),
            tray.name
        )
        panelViewModels[trayID]?.showToast(message)
        saveSnapshot()
    }

    private func reorderItem(itemID: UUID, in trayID: UUID, to index: Int) {
        guard let tray = listViewModel.trays.first(where: { $0.id == trayID }),
              let item = listViewModel.items(for: tray).first(where: { $0.id == itemID })
        else { return }
        listViewModel.reorder(url: item.url, in: trayID, to: index)
        listViewModel.reevaluateSmart()
        refreshAllPanelContents()
        saveSnapshot()
    }

    private func moveItem(itemID: UUID, from fromTrayID: UUID, to toTrayID: UUID) {
        guard let fromTray = listViewModel.trays.first(where: { $0.id == fromTrayID }),
              let item = listViewModel.items(for: fromTray).first(where: { $0.id == itemID })
        else { return }
        listViewModel.move(url: item.url, from: fromTrayID, to: toTrayID)
        listViewModel.reevaluateSmart()
        refreshAllPanelContents()
        refreshTabRail()
        if let toTray = listViewModel.trays.first(where: { $0.id == toTrayID }) {
            let message = String(
                format: NSLocalizedString("toast.added", comment: ""),
                toTray.name
            )
            panelViewModels[toTrayID]?.showToast(message)
        }
        saveSnapshot()
    }

    /// ドラッグ移動・リサイズで確定した frame を永続化する。
    private func handleTrayFrameChanged(trayID: UUID, frame: CGRect) {
        guard let tray = listViewModel.trays.first(where: { $0.id == trayID }) else { return }
        listViewModel.updateLayout(trayID: trayID, frame: TrayFrame(frame), collapsed: tray.isCollapsed)
        saveSnapshot()
    }

    private func refreshAllPanelContents() {
        for tray in listViewModel.trays {
            overlayManager.updateContent(for: tray.id)
        }
    }

    private func handleDesktopChanged() {
        let items = scanner.scanDesktop()
        listViewModel.updateDesktopItems(items)
        snapshot.trays = listViewModel.trays
        snapshot = persistence.markStaleItems(
            in: snapshot,
            existingURLs: listViewModel.existingURLs
        )
        listViewModel.setTrays(snapshot.trays)
        refreshAllPanelContents()
        refreshTabRail()
        saveSnapshot()
    }

    private func toggleVisibility() {
        if listViewModel.expandedTrays.isEmpty {
            expandAll()
        } else {
            collapseAll()
        }
    }

    private func saveSnapshot() {
        snapshot.trays = listViewModel.trays
        try? persistence.saveSync(snapshot)
    }

    @objc private func screensChanged() {
        overlayManager.clampAllToVisibleFrames()
        refreshTabRail()
    }
}

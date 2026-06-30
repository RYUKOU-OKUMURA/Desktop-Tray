import Foundation

/// 全トレイ一覧・作成/削除・全展開/全収納を管理する ViewModel（アーキテクチャ v0.1 §3.3）。
@MainActor
@Observable
final class TrayListViewModel {
    /// 全トレイ（手動 + スマート）。
    var trays: [Tray] = []

    /// Desktop 直下の実在アイテム。
    var desktopItems: [DesktopItem] = []

    /// 実在 URL 集合（stale 判定用）。
    var existingURLs: Set<URL> {
        Set(desktopItems.map(\.url))
    }

    /// 各スマートトレイの評価結果。
    var smartResults: [UUID: [TrayItem]] = [:]

    private let engine: TrayEngine
    private let evaluator: SmartTrayEvaluator

    init(engine: TrayEngine = TrayEngine(), evaluator: SmartTrayEvaluator = SmartTrayEvaluator()) {
        self.engine = engine
        self.evaluator = evaluator
    }

    /// デスクトップアイテムを更新し、スマート評価を再実行する。
    func updateDesktopItems(_ items: [DesktopItem]) {
        desktopItems = items
        reevaluateSmart()
    }

    /// スマートトレイ評価を再実行。
    func reevaluateSmart() {
        smartResults = evaluator.evaluate(items: desktopItems, trays: trays)
    }

    /// トレイを差し替え、スマート評価を再実行。
    func setTrays(_ newTrays: [Tray]) {
        trays = newTrays
        reevaluateSmart()
    }

    /// 新規トレイ作成（要件定義 §7.1）。
    @discardableResult
    func createTray(name: String, color: TrayColor? = nil) -> Tray {
        let manualCount = trays.filter { !$0.isSmart }.count
        let chosen = color ?? TrayTheme.palette[manualCount % TrayTheme.palette.count]
        let visible = LayoutEngine.combinedVisibleFrame()
        let frame = TrayFrame(
            x: visible.minX + 80,
            y: visible.midY - 150,
            width: 400,
            height: 300
        )
        let tray = engine.createTray(name: name, color: chosen, frame: frame, in: &trays)
        return tray
    }

    /// トレイ削除。
    func deleteTray(id: UUID) {
        engine.deleteTray(id: id, in: &trays)
    }

    /// ファイルをトレイへ追加（非破壊）。
    func assign(url: URL, to trayID: UUID) {
        engine.assignToTray(url: url, to: trayID, in: &trays)
    }

    /// トレイから外す。
    func unassign(url: URL, from trayID: UUID) {
        engine.removeFromTray(url: url, from: trayID, in: &trays)
    }

    /// トレイ間移動。
    func move(url: URL, from: UUID, to: UUID) {
        engine.moveBetweenTrays(url: url, from: from, to: to, in: &trays)
    }

    /// トレイ内並び替え。
    func reorder(url: URL, in trayID: UUID, to index: Int) {
        engine.reorder(url: url, in: trayID, to: index, in: &trays)
    }

    /// トレイレイアウト更新。
    func updateLayout(trayID: UUID, frame: TrayFrame, collapsed: Bool) {
        engine.updateTrayLayout(trayID: trayID, frame: frame, collapsed: collapsed, in: &trays)
        engine.reindexCollapsedTabs(in: &trays)
    }

    /// 全展開。
    func expandAll() {
        engine.expandAll(in: &trays)
    }

    /// 全収納。
    func collapseAll() {
        engine.collapseAll(in: &trays)
    }

    /// 収納中トレイ一覧。
    var collapsedTrays: [Tray] {
        trays.filter(\.isCollapsed).sorted { $0.tabIndex < $1.tabIndex }
    }

    /// 展開中トレイ一覧。
    var expandedTrays: [Tray] {
        trays.filter { !$0.isCollapsed }
    }

    /// 指定トレイの表示用アイテム（手動は membership、スマートは評価結果）。
    func items(for tray: Tray) -> [TrayItem] {
        switch tray.type {
        case .manual: return tray.items
        case .smart:  return smartResults[tray.id] ?? []
        }
    }
}

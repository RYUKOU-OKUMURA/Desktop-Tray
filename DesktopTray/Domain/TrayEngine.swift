import Foundation

/// トレイ操作エンジン（アーキテクチャ v0.1 §3.4）。
/// **非破壊の担保**: 提供する操作は次に限定し、ファイルシステムを変更する API は持たない。
///
/// - `assignToTray(url, trayId)`
/// - `removeFromTray(url, trayId)`
/// - `reorder(url, trayId, newIndex)`
/// - `moveBetweenTrays(url, fromTrayId, toTrayId)`
/// - `updateTrayLayout(trayId, frame, collapsed)`
struct TrayEngine: Sendable {
    /// 手動トレイへ URL を追加。既に存在する場合は no-op。
    @discardableResult
    func assignToTray(url: URL, to trayID: UUID, in trays: inout [Tray]) -> Bool {
        guard let idx = trays.firstIndex(where: { $0.id == trayID && $0.type == .manual }) else {
            return false
        }
        if trays[idx].items.contains(where: { $0.url == url }) {
            return false
        }
        let sortIndex = trays[idx].items.count
        trays[idx].items.append(TrayItem(url: url, sortIndex: sortIndex))
        return true
    }

    /// 手動トレイから URL を除外。ファイル実体は削除されない。
    @discardableResult
    func removeFromTray(url: URL, from trayID: UUID, in trays: inout [Tray]) -> Bool {
        guard let idx = trays.firstIndex(where: { $0.id == trayID && $0.type == .manual }) else {
            return false
        }
        let before = trays[idx].items.count
        trays[idx].items.removeAll { $0.url == url }
        reindex(in: &trays[idx])
        return trays[idx].items.count != before
    }

    /// トレイ内で URL を newIndex へ並び替え。表示順のみ保存。
    @discardableResult
    func reorder(url: URL, in trayID: UUID, to newIndex: Int, in trays: inout [Tray]) -> Bool {
        guard let idx = trays.firstIndex(where: { $0.id == trayID && $0.type == .manual }) else {
            return false
        }
        let items = trays[idx].items
        guard let current = items.firstIndex(where: { $0.url == url }) else { return false }
        guard newIndex >= 0, newIndex <= items.count - 1, current != newIndex else { return false }

        var mutable = items
        let item = mutable.remove(at: current)
        mutable.insert(item, at: newIndex)
        trays[idx].items = mutable
        reindex(in: &trays[idx])
        return true
    }

    /// トレイ間移動。所属トレイだけ変更し、ファイル実体は移動しない（要件定義 §7.3）。
    @discardableResult
    func moveBetweenTrays(
        url: URL,
        from fromID: UUID,
        to toID: UUID,
        in trays: inout [Tray]
    ) -> Bool {
        guard fromID != toID else { return false }
        guard let fromIdx = trays.firstIndex(where: { $0.id == fromID && $0.type == .manual }) else {
            return false
        }
        guard let toIdx = trays.firstIndex(where: { $0.id == toID && $0.type == .manual }) else {
            return false
        }
        guard let itemIdx = trays[fromIdx].items.firstIndex(where: { $0.url == url }) else {
            return false
        }
        if trays[toIdx].items.contains(where: { $0.url == url }) {
            // 移動先に既に存在する場合は移動元から削除だけ行う
            trays[fromIdx].items.remove(at: itemIdx)
            reindex(in: &trays[fromIdx])
            return true
        }
        var item = trays[fromIdx].items.remove(at: itemIdx)
        item.sortIndex = trays[toIdx].items.count
        trays[toIdx].items.append(item)
        reindex(in: &trays[fromIdx])
        return true
    }

    /// トレイのレイアウト（frame / 収納状態）を更新。
    func updateTrayLayout(
        trayID: UUID,
        frame: TrayFrame,
        collapsed: Bool,
        in trays: inout [Tray]
    ) {
        guard let idx = trays.firstIndex(where: { $0.id == trayID }) else { return }
        trays[idx].frame = frame
        trays[idx].isCollapsed = collapsed
    }

    /// 新規トレイを作成して追加。
    @discardableResult
    func createTray(
        name: String,
        color: TrayColor,
        frame: TrayFrame,
        in trays: inout [Tray]
    ) -> Tray {
        let tray = Tray(
            name: name,
            type: .manual,
            color: color,
            frame: frame
        )
        trays.append(tray)
        return tray
    }

    /// トレイを削除。ファイル実体には影響しない。
    @discardableResult
    func deleteTray(id: UUID, in trays: inout [Tray]) -> Bool {
        let before = trays.count
        trays.removeAll { $0.id == id }
        return trays.count != before
    }

    /// トレイ名を変更する。
    @discardableResult
    func renameTray(id: UUID, name: String, in trays: inout [Tray]) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard let idx = trays.firstIndex(where: { $0.id == id }) else { return false }
        guard trays[idx].name != trimmed else { return false }
        trays[idx].name = trimmed
        return true
    }

    /// 全トレイを展開状態へ。
    func expandAll(in trays: inout [Tray]) {
        for idx in trays.indices {
            trays[idx].isCollapsed = false
        }
    }

    /// 全トレイを収納状態へ。tabIndex を再採番する。
    func collapseAll(in trays: inout [Tray]) {
        var tabIdx = 0
        for idx in trays.indices {
            trays[idx].isCollapsed = true
            trays[idx].tabIndex = tabIdx
            tabIdx += 1
        }
    }

    /// 収納タブ順を再採番する。
    func reindexCollapsedTabs(in trays: inout [Tray]) {
        var tabIdx = 0
        for idx in trays.indices where trays[idx].isCollapsed {
            trays[idx].tabIndex = tabIdx
            tabIdx += 1
        }
    }

    /// 手動トレイ内の sortIndex を 0...N-1 に詰める。
    private func reindex(in tray: inout Tray) {
        for i in tray.items.indices {
            tray.items[i].sortIndex = i
        }
    }
}

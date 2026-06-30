import AppKit
import Foundation

/// 1 トレイの UI 状態を管理する ViewModel（アーキテクチャ v0.1 §3.3）。
/// ファイルパス文字列を View に直接渡さず `TrayItemPresentation` へ変換する。
@MainActor
@Observable
final class TrayPanelViewModel {
    let trayID: UUID
    private let fileActions: FileActionsService
    private let iconProvider: IconProvider

    /// 表示用アイテム群。手動トレイは membership、スマートトレイは評価結果を格納。
    var presentations: [TrayItemPresentation] = []

    /// ドロップ/解除時のフィードバックメッセージ（nil で非表示）。
    var toastMessage: String?

    /// キャッシュされたアイコン。
    private var iconCache: [UUID: NSImage] = [:]

    init(
        trayID: UUID,
        fileActions: FileActionsService = .shared,
        iconProvider: IconProvider = .shared
    ) {
        self.trayID = trayID
        self.fileActions = fileActions
        self.iconProvider = iconProvider
    }

    /// トレイとスマート評価結果・実在 URL 集合から表示用アイテムを構築する。
    func update(
        from tray: Tray,
        smartItems: [TrayItem],
        existingURLs: Set<URL>
    ) {
        let sourceItems: [TrayItem]
        switch tray.type {
        case .manual:
            sourceItems = tray.items
        case .smart:
            sourceItems = smartItems
        }

        presentations = sourceItems.map { item in
            let name = item.url.lastPathComponent
            let isDir = (try? item.url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let stale = !existingURLs.contains(item.url) || item.stale
            return TrayItemPresentation(
                id: item.id,
                displayName: name,
                isDirectory: isDir,
                stale: stale,
                sortIndex: item.sortIndex
            )
        }
        presentations.sort { $0.sortIndex < $1.sortIndex }

        // アイコンキャッシュ更新
        for item in sourceItems {
            if iconCache[item.id] == nil {
                if let icon = iconProvider.icon(for: item.url) {
                    iconCache[item.id] = icon
                }
            }
        }
        // 不要なキャッシュ除去
        let ids = Set(sourceItems.map(\.id))
        iconCache = iconCache.filter { ids.contains($0.key) }
    }

    /// 指定プレゼンテーションから元 URL を復元（ダブルクリック open 用）。
    /// presentations 生成元の sourceItems を外部で保持している前提で、
    /// 呼び出し元が URL を渡す設計も許容する。ここでは presentations に URL を持たせないため、
    /// `open(url:)` の直接的な API を提供する。
    func open(url: URL) {
        fileActions.open(url)
    }

    func reveal(url: URL) {
        fileActions.reveal(url)
    }

    func icon(for presentation: TrayItemPresentation) -> NSImage? {
        iconCache[presentation.id]
    }

    /// トーストを表示する。
    func showToast(_ message: String) {
        toastMessage = message
    }
}

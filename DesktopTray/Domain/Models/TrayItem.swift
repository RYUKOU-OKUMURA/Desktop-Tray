import Foundation

/// トレイ内の1アイテム。ファイル実体への参照のみを持ち、実体は移動しない（要件定義 §2.1）。
struct TrayItem: Codable, Sendable, Identifiable, Equatable, Hashable {
    let id: UUID
    /// デスクトップ上のファイル/フォルダへの URL。非破壊参照。
    var url: URL
    var sortIndex: Int
    /// Desktop 上に存在しない場合（削除/改名検出時）に true になる。
    var stale: Bool

    init(
        id: UUID = UUID(),
        url: URL,
        sortIndex: Int = 0,
        stale: Bool = false
    ) {
        self.id = id
        self.url = url
        self.sortIndex = sortIndex
        self.stale = stale
    }

    /// 保存用 URL（簡易 accesible bookmark は Phase 4 で導入）。
    var bookmarkablePath: String { url.path }
}

/// 表示用に変換されたアイテム。ViewModel から View へ渡す（アーキテクチャ v0.1 §3.3）。
/// ファイルパス生文字列を View に渡さないための中間表現。
struct TrayItemPresentation: Sendable, Identifiable, Equatable {
    let id: UUID
    let displayName: String
    let isDirectory: Bool
    let stale: Bool
    let sortIndex: Int
}

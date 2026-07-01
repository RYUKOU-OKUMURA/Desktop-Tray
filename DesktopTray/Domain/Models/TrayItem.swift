import CryptoKit
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

    /// URL から決定論的に導出した ID（同じ URL なら常に同じ値）。
    /// `SmartTrayEvaluator` はルール評価のたびに `TrayItem` を作り直すため、`UUID()` の
    /// ランダム生成のままだと再評価ごとに ID が変わってしまい、ドラッグ中の識別子
    /// （`TrayItemTransfer.itemID`）やアイコンキャッシュが再評価のたびに無効化されてしまう
    /// （不具合修正: スマートトレイからのドラッグ移動）。MD5 ハッシュの16バイトをそのまま
    /// UUID として使うことで、非暗号用途の決定論的 ID を得る。
    static func stableID(for url: URL) -> UUID {
        let digest = Array(Insecure.MD5.hash(data: Data(url.absoluteString.utf8)))
        return UUID(uuid: (
            digest[0], digest[1], digest[2], digest[3],
            digest[4], digest[5], digest[6], digest[7],
            digest[8], digest[9], digest[10], digest[11],
            digest[12], digest[13], digest[14], digest[15]
        ))
    }
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

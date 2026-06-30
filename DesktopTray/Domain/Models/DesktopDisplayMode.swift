import Foundation

/// デスクトップ表示モード（要件定義 §10 / アーキテクチャ v0.1 §7）。
/// MVP は `.safe` 固定。`.clean`（スッキリモード）は Phase 4 以降。
enum DesktopDisplayMode: String, Codable, Sendable, CaseIterable {
    case safe
    case clean

    /// MVP でユーザーに提示するのは `.safe` のみ。
    static var mvpDefault: DesktopDisplayMode { .safe }
}

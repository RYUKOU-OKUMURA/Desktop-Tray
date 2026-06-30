import AppKit
import Foundation

/// ファイル操作サービス。**非破壊**原則に従い、`open` / `reveal` のみを提供する
/// （アーキテクチャ v0.1 §3.5 / 技術スタック v0.1 §4）。
/// `move` / `remove` / `rename` などのファイルシステム変更 API は持たない。
final class FileActionsService: @unchecked Sendable {
    static let shared = FileActionsService()

    /// macOS 標準の関連アプリで開く（要件定義 §7.5）。
    @discardableResult
    func open(_ url: URL) -> Bool {
        NSWorkspace.shared.open(url)
    }

    /// Finder で表示（要件定義 §7.6）。
    /// 指定ファイルを選択状態で開く。
    func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// ファイルが存在するか。
    func fileExists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }
}

import AppKit
import Foundation

/// `NSWorkspace.shared.icon(forFile:)` で標準アイコンを取得する（技術スタック v0.1 §5）。
/// 同じ URL への反復取得をキャッシュし、500 件規模でも性能を保つ（要件定義 §13.1）。
final class IconProvider: @unchecked Sendable {
    static let shared = IconProvider()

    private let cache = NSCache<NSURL, NSImage>()
    private let lock = NSLock()

    init() {
        cache.countLimit = 256
    }

    /// 指定 URL のアイコンを返す。存在しない・取得失敗時は nil。
    /// フォルダは汎用フォルダアイコン、ファイルは種別アイコン。
    func icon(for url: URL) -> NSImage? {
        let path = url.path
        guard FileManager.default.fileExists(atPath: path) else {
            return nil
        }

        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }

        lock.lock()
        defer { lock.unlock() }

        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }

        let icon = NSWorkspace.shared.icon(forFile: path)
        icon.size = NSSize(width: TrayTheme.itemIconSize, height: TrayTheme.itemIconSize)
        cache.setObject(icon, forKey: url as NSURL)
        return icon
    }

    /// URL が削除/改名されたときにキャッシュを破棄する。
    func invalidate(for url: URL) {
        cache.removeObject(forKey: url as NSURL)
    }

    /// 全キャッシュクリア（Desktop 再スキャン時など）。
    func clear() {
        cache.removeAllObjects()
    }
}

import Foundation

/// 永続化ストア。JSON (Codable) で `~/Library/Application Support/DesktopTray/` 配下に読み書きする
/// （アーキテクチャ v0.1 §5 / 技術スタック v0.1 §7）。
/// 保存するのはファイル本体ではなくメタデータのみ（要件定義 §11）。
final class PersistenceStore: @unchecked Sendable {
    struct Snapshot: Codable, Sendable {
        var schemaVersion: Int
        var trays: [Tray]
        var displayMode: DesktopDisplayMode
    }

    static let currentSchemaVersion: Int = 1

    private let directoryURL: URL
    private let traysURL: URL
    private let settingsURL: URL
    private let schemaVersionURL: URL
    private let fileManager: FileManager
    private let queue: DispatchQueue

    init(
        directoryURL: URL? = nil,
        fileManager: FileManager = .default,
        queue: DispatchQueue = .global(qos: .utility)
    ) {
        let dir = directoryURL ?? fileManager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("DesktopTray", isDirectory: true)
        self.directoryURL = dir
        self.traysURL = dir.appendingPathComponent("trays.json")
        self.settingsURL = dir.appendingPathComponent("settings.json")
        self.schemaVersionURL = dir.appendingPathComponent("schema-version.txt")
        self.fileManager = fileManager
        self.queue = queue
    }

    /// 保存ディレクトリが無ければ作成する。
    func ensureDirectory() throws {
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
    }

    /// 同期ロード。初回起動時などに使う。失敗時は空スナップショット。
    func loadSync() -> Snapshot {
        guard let data = try? Data(contentsOf: traysURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data)
        else {
            return Snapshot(
                schemaVersion: Self.currentSchemaVersion,
                trays: Self.defaultTrays(),
                displayMode: .mvpDefault
            )
        }
        return snapshot
    }

    /// 非同期ロード。
    func load() async -> Snapshot {
        await withCheckedContinuation { (continuation: CheckedContinuation<Snapshot, Never>) in
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: Snapshot(
                        schemaVersion: Self.currentSchemaVersion,
                        trays: Self.defaultTrays(),
                        displayMode: .mvpDefault
                    ))
                    return
                }
                let snapshot = self.loadSync()
                continuation.resume(returning: snapshot)
            }
        }
    }

    /// 同期保存。ファイル書き込みはアトミック。失敗時はエラーを投げる。
    func saveSync(_ snapshot: Snapshot) throws {
        try ensureDirectory()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        try data.write(to: traysURL, options: [.atomic])

        try "\(snapshot.schemaVersion)".write(
            to: schemaVersionURL,
            atomically: true,
            encoding: .utf8
        )
    }

    /// 非同期保存。
    func save(_ snapshot: Snapshot) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: PersistenceError.unknown)
                    return
                }
                do {
                    try self.saveSync(snapshot)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// 永続化された手動トレイ membership に含まれない URL を `stale` 化する
    /// （アーキテクチャ v0.1 §5.3）。
    func markStaleItems(in snapshot: Snapshot, existingURLs: Set<URL>) -> Snapshot {
        var new = snapshot
        for idx in new.trays.indices {
            guard new.trays[idx].type == .manual else { continue }
            for itemIdx in new.trays[idx].items.indices {
                let url = new.trays[idx].items[itemIdx].url
                new.trays[idx].items[itemIdx].stale = !existingURLs.contains(url)
            }
        }
        return new
    }

    /// 全データ破棄（リセット用）。
    func reset() throws {
        try? fileManager.removeItem(at: traysURL)
        try? fileManager.removeItem(at: settingsURL)
        try? fileManager.removeItem(at: schemaVersionURL)
    }

    // MARK: - Defaults

    /// 初回起動時のデフォルトトレイ（要件定義 §5.3 / §9.2）。
    /// 手動トレイ5種 + スマートトレイプリセット5種。
    /// スクリーンショットはスマートトレイとして提供するため手動には含めない。
    static func defaultTrays() -> [Tray] {
        let visible = LayoutEngine.primaryScreenVisibleFrame()
        let width: CGFloat = 400
        let height: CGFloat = 300
        let startX: CGFloat = visible.minX + 80
        let startY: CGFloat = visible.maxY - height - 40

        var trays: [Tray] = [
            Tray(
                name: NSLocalizedString("tray.readLater", comment: ""),
                type: .manual,
                color: .blue,
                frame: TrayFrame(x: startX, y: startY, width: width, height: height),
                tabIndex: 0
            ),
            Tray(
                name: NSLocalizedString("tray.assets", comment: ""),
                type: .manual,
                color: .purple,
                frame: TrayFrame(x: startX + width + 20, y: startY, width: width, height: height),
                tabIndex: 1
            ),
            Tray(
                name: NSLocalizedString("tray.inProgress", comment: ""),
                type: .manual,
                color: .orange,
                frame: TrayFrame(x: startX, y: startY - height - 20, width: width, height: height),
                tabIndex: 2
            ),
            Tray(
                name: NSLocalizedString("tray.temp", comment: ""),
                type: .manual,
                color: .teal,
                frame: TrayFrame(x: startX + width + 20, y: startY - height - 20, width: width, height: height),
                tabIndex: 3
            ),
            Tray(
                name: NSLocalizedString("tray.other", comment: ""),
                type: .manual,
                color: .gray,
                frame: TrayFrame(x: startX, y: startY - (height + 20) * 2, width: width, height: height),
                tabIndex: 4
            ),
        ]

        // スマートトレイプリセットを付加
        trays.append(contentsOf: SmartTrayPresets.all)
        return trays
    }
}

enum PersistenceError: Error {
    case unknown
}

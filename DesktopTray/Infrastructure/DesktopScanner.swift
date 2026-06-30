import Foundation

/// デスクトップ直下のファイル/フォルダ1件のメタデータ。
/// フォルダ内部はスキャンしない（要件定義 §5.1）。
struct DesktopItem: Sendable, Identifiable, Equatable, Hashable {
    let url: URL
    let name: String
    let isDirectory: Bool
    let creationDate: Date?
    let contentModificationDate: Date?

    var id: URL { url }

    var fileExtension: String {
        url.pathExtension.lowercased()
    }

    /// ファイル名（拡張子含む）。
    var displayName: String { name }
}

/// `~/Desktop` 直下を列挙して `DesktopItem` 化する（アーキテクチャ v0.1 §3.5）。
/// フォルダ内部は掘らない。MVP は直下のみ。
final class DesktopScanner: @unchecked Sendable {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// デスクトップフォルダの URL。`~/Desktop`。
    var desktopURL: URL {
        fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
    }

    /// デスクトップ直下を列挙する。失敗時は空配列。
    /// 隠しファイル（`.` 始まり）は除外しないが、`.DS_Store` と `.localized` は除外する。
    func scanDesktop() -> [DesktopItem] {
        let url = desktopURL
        guard let contents = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [
                .isDirectoryKey,
                .creationDateKey,
                .contentModificationDateKey
            ],
            options: [.skipsSubdirectoryDescendants]
        ) else {
            return []
        }

        return contents.compactMap { fileURL in
            let name = fileURL.lastPathComponent
            if name == ".DS_Store" || name == ".localized" { return nil }

            let values = try? fileURL.resourceValues(forKeys: [
                .isDirectoryKey,
                .creationDateKey,
                .contentModificationDateKey
            ])

            return DesktopItem(
                url: fileURL,
                name: name,
                isDirectory: values?.isDirectory ?? false,
                creationDate: values?.creationDate,
                contentModificationDate: values?.contentModificationDate
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

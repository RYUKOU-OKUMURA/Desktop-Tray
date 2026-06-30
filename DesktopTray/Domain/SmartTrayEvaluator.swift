import Foundation

/// スマートトレイ評価エンジン（アーキテクチャ v0.1 §3.4 / §6 / §4.3）。
/// 結果は保存せず都度計算。同一ファイルが複数トレイに表示されるのは仕様どおり（要件定義 §9.5）。
/// 評価は呼び出し元でバックグラウンドキューに乗せることを想定（本型自体は pure でスレッド安全）。
struct SmartTrayEvaluator: Sendable {
    /// 指定デスクトップアイテム群に対する各スマートトレイの評価結果を返す。
    /// 戻り値: `[Tray.id: [TrayItem]]`。手動トレイは含めない。
    func evaluate(items: [DesktopItem], trays: [Tray]) -> [UUID: [TrayItem]] {
        let smartTrays = trays.filter { $0.isSmart }
        let manualAssignedURLs = collectManualAssignedURLs(trays: trays)

        // まず uncategorized 以外を評価
        var results: [UUID: [TrayItem]] = [:]
        var allMatchedURLs: Set<URL> = []

        for tray in smartTrays {
            guard let rule = tray.rule else { continue }
            guard case .uncategorized = rule.kind else {
                let matched = items.filter { matches(rule: rule, item: $0) }
                let trayItems = matched.enumerated().map { idx, item in
                    TrayItem(url: item.url, sortIndex: idx)
                }
                results[tray.id] = trayItems
                allMatchedURLs.formUnion(matched.map(\.url))
                continue
            }
        }

        // uncategorized を最後に評価（他スマートルール非該当 かつ 手動未所属）
        for tray in smartTrays {
            guard let rule = tray.rule, case .uncategorized = rule.kind else { continue }
            let uncategorized = items.filter { item in
                !manualAssignedURLs.contains(item.url) && !allMatchedURLs.contains(item.url)
            }
            let trayItems = uncategorized.enumerated().map { idx, item in
                TrayItem(url: item.url, sortIndex: idx)
            }
            results[tray.id] = trayItems
        }

        return results
    }

    /// 単一ルールの評価。`uncategorized` は `evaluate` 内で全体を見て処理するため、
    /// ここでは常に `false` を返す（個別 item 判定不能）。
    func matches(rule: SmartTrayRule, item: DesktopItem) -> Bool {
        switch rule.kind {
        case .filenameContainsAny(let needles):
            let lowerName = item.name.lowercased()
            return needles.contains { needle in
                lowerName.contains(needle.lowercased())
            }
        case .fileExtensionIn(let exts):
            let lowered = exts.map { $0.lowercased() }
            return lowered.contains(item.fileExtension)
        case .createdWithinDays(let days):
            guard let created = item.creationDate else { return false }
            let cutoff = Date().addingTimeInterval(-Double(days) * 86_400)
            return created >= cutoff
        case .uncategorized:
            return false
        }
    }

    /// 手動トレイに所属している全 URL を集める。
    private func collectManualAssignedURLs(trays: [Tray]) -> Set<URL> {
        var urls: Set<URL> = []
        for tray in trays where tray.type == .manual {
            for item in tray.items {
                urls.insert(item.url)
            }
        }
        return urls
    }
}

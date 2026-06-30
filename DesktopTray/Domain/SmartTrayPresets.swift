import Foundation

/// MVP 用スマートトレイプリセット5種（要件定義 §9.2 / アーキテクチャ v0.1 §6.2）。
/// 初回起動時に手動トレイと合わせて生成される。
enum SmartTrayPresets {
    /// スクリーンショット: ファイル名に「スクリーンショット」or「Screenshot」を含む。
    static var screenshots: Tray {
        Tray(
            name: NSLocalizedString("smart.screenshots", comment: ""),
            type: .smart,
            color: .pink,
            frame: TrayFrame(x: 980, y: 80, width: 400, height: 260),
            rule: SmartTrayRule(kind: .filenameContainsAny(["スクリーンショット", "Screenshot"]))
        )
    }

    /// PDF: 拡張子 .pdf。
    static var pdf: Tray {
        Tray(
            name: NSLocalizedString("smart.pdf", comment: ""),
            type: .smart,
            color: .red,
            frame: TrayFrame(x: 980, y: 360, width: 400, height: 260),
            rule: SmartTrayRule(kind: .fileExtensionIn(["pdf"]))
        )
    }

    /// 画像: .png/.jpg/.jpeg/.webp/.heic/.gif。
    static var images: Tray {
        Tray(
            name: NSLocalizedString("smart.images", comment: ""),
            type: .smart,
            color: .green,
            frame: TrayFrame(x: 980, y: 640, width: 400, height: 260),
            rule: SmartTrayRule(
                kind: .fileExtensionIn(["png", "jpg", "jpeg", "webp", "heic", "gif"])
            )
        )
    }

    /// 最近追加: 作成日 or 更新日が過去7日以内。
    static var recent: Tray {
        Tray(
            name: NSLocalizedString("smart.recent", comment: ""),
            type: .smart,
            color: .orange,
            frame: TrayFrame(x: 540, y: 640, width: 400, height: 260),
            rule: SmartTrayRule(kind: .createdWithinDays(7))
        )
    }

    /// 未分類: 手動未所属 かつ 上記スマートルール非該当。
    static var uncategorized: Tray {
        Tray(
            name: NSLocalizedString("smart.uncategorized", comment: ""),
            type: .smart,
            color: .gray,
            frame: TrayFrame(x: 120, y: 640, width: 400, height: 260),
            rule: SmartTrayRule(kind: .uncategorized)
        )
    }

    /// 全プリセットを配列で返す。生成順は screenshots -> pdf -> images -> recent -> uncategorized。
    /// uncategorized は最後に評価される必要があるため、配列の末尾に置く。
    /// 補助修正: 起動直後の散らかりを防ぐため、スマート5種は初期収納状態（左端タブ化）で生成する。
    static var all: [Tray] {
        [screenshots, pdf, images, recent, uncategorized].enumerated().map { idx, tray in
            var t = tray
            t.isCollapsed = true
            t.tabIndex = idx
            return t
        }
    }
}

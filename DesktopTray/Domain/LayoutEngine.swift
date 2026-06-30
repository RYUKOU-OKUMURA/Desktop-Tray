import AppKit
import Foundation

/// トレイ配置計算エンジン。Window Orchestration 層から利用される。
/// 収納/展開時の frame 計算と左端 snap 判定を担う（アーキテクチャ v0.1 §3.4 / §4.4）。
struct LayoutEngine: Sendable {
    /// 左端 snap 判定閾値（要件定義 §8.1）。
    let snapThreshold: CGFloat

    /// 収納タブの幅。
    let collapsedTabWidth: CGFloat

    /// 左レールの幅。
    let sideRailWidth: CGFloat

    /// トレイ高さの最小値。
    let minTrayHeight: CGFloat

    init(
        snapThreshold: CGFloat = TrayTheme.snapThreshold,
        collapsedTabWidth: CGFloat = TrayTheme.collapsedTabWidth,
        sideRailWidth: CGFloat = TrayTheme.sideRailWidth,
        minTrayHeight: CGFloat = TrayTheme.trayHeightRange.lowerBound
    ) {
        self.snapThreshold = snapThreshold
        self.collapsedTabWidth = collapsedTabWidth
        self.sideRailWidth = sideRailWidth
        self.minTrayHeight = minTrayHeight
    }

    /// トレイが左端 snap 領域に入ったか。
    /// `frame.minX` が左レール右端から snapThreshold 以内なら snap 対象。
    func shouldSnap(frame: CGRect) -> Bool {
        frame.minX <= sideRailWidth + snapThreshold
    }

    /// 収納時の左端タブ frame を計算。
    /// `index` は収納タブの並び順（0始まり）。タブは左レールの右に縦に並ぶ。
    func collapsedTabFrame(index: Int, screen: CGRect) -> CGRect {
        let tabHeight: CGFloat = 96
        let spacing: CGFloat = 8
        let topPadding: CGFloat = 16
        // NSRect は左下原点。screen の上端から topPadding + index*(tabHeight+spacing) 下がった位置。
        let y = screen.maxY - topPadding - CGFloat(index + 1) * tabHeight - CGFloat(index) * spacing
        return CGRect(
            x: sideRailWidth,
            y: y,
            width: collapsedTabWidth,
            height: tabHeight
        )
    }

    /// 展開時の frame を復元。画面外にはみ出る場合は可視領域内へ clamp する。
    func expandedFrame(saved: CGRect, screen: CGRect) -> CGRect {
        var rect = saved
        // 画面外左
        if rect.minX < sideRailWidth + collapsedTabWidth {
            rect.origin.x = sideRailWidth + collapsedTabWidth + 8
        }
        // 画面外右
        if rect.maxX > screen.maxX {
            rect.origin.x = screen.maxX - rect.width - 8
        }
        // 画面外下
        if rect.minY < screen.minY {
            rect.origin.y = screen.minY + 8
        }
        // 画面外上
        if rect.maxY > screen.maxY {
            rect.origin.y = screen.maxY - rect.height - 8
        }
        // 最小高さの保証
        if rect.height < minTrayHeight {
            rect.size.height = minTrayHeight
        }
        return rect
    }

    /// 全スクリーンの visibleFrame を統合したバウンディング矩形を返す。
    /// 外部ディスプレイ切断時にトレイが画面外に残らないよう（要件定義 §13.2）。
    static func combinedVisibleFrame() -> CGRect {
        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            return CGRect(x: 0, y: 0, width: 1440, height: 900)
        }
        var union = screens[0].visibleFrame
        for screen in screens.dropFirst() {
            union = union.union(screen.visibleFrame)
        }
        return union
    }

    /// 指定 frame を combinedVisibleFrame 内へ clamp。
    func clampToVisibleFrames(_ frame: CGRect) -> CGRect {
        let visible = Self.combinedVisibleFrame()
        var rect = frame

        if rect.width > visible.width { rect.size.width = visible.width - 16 }
        if rect.height > visible.height { rect.size.height = visible.height - 16 }

        if rect.minX < visible.minX { rect.origin.x = visible.minX + 8 }
        if rect.maxX > visible.maxX { rect.origin.x = visible.maxX - rect.width - 8 }
        if rect.minY < visible.minY { rect.origin.y = visible.minY + 8 }
        if rect.maxY > visible.maxY { rect.origin.y = visible.maxY - rect.height - 8 }

        return rect
    }
}

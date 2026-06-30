import Foundation
import SwiftUI

/// SwiftUI Preview 用モックデータ（アーキテクチャ v0.1 §3.1 / Phase 1 完了条件）。
/// 実ファイル連携なしで「気持ちいいトレイ」を再現するためのダミー。
enum MockTrayData {
    static let pdf = URL(fileURLWithPath: "/Users/demo/Desktop/sample.pdf")
    static let png = URL(fileURLWithPath: "/Users/demo/Desktop/spec.png")
    static let folder = URL(fileURLWithPath: "/Users/demo/Desktop/project")

    static var readLater: Tray {
        Tray(
            name: "あとで読む",
            type: .manual,
            color: .blue,
            frame: TrayFrame(x: 120, y: 80, width: 400, height: 300),
            items: [
                TrayItem(url: pdf, sortIndex: 0),
                TrayItem(url: png, sortIndex: 1),
            ]
        )
    }

    static var assets: Tray {
        Tray(
            name: "素材",
            type: .manual,
            color: .purple,
            frame: TrayFrame(x: 540, y: 80, width: 420, height: 280),
            items: [
                TrayItem(url: png, sortIndex: 0),
            ]
        )
    }

    static var screenshots: Tray {
        Tray(
            name: "スクリーンショット",
            type: .smart,
            color: .pink,
            frame: TrayFrame(x: 120, y: 400, width: 400, height: 260),
            rule: SmartTrayRule(kind: .filenameContainsAny(["スクリーンショット", "Screenshot"]))
        )
    }

    static var allTrays: [Tray] {
        [readLater, assets, screenshots]
    }

    static var collapsedTrays: [Tray] {
        [
            Tray(
                name: "あとで読む",
                type: .manual,
                color: .blue,
                frame: TrayFrame(width: 400, height: 300),
                isCollapsed: true,
                tabIndex: 0
            ),
            Tray(
                name: "素材",
                type: .manual,
                color: .purple,
                frame: TrayFrame(width: 420, height: 280),
                isCollapsed: true,
                tabIndex: 1
            ),
        ]
    }

    static var samplePresentations: [TrayItemPresentation] {
        [
            TrayItemPresentation(
                id: UUID(),
                displayName: "spec.pdf",
                isDirectory: false,
                stale: false,
                sortIndex: 0
            ),
            TrayItemPresentation(
                id: UUID(),
                displayName: "design.png",
                isDirectory: false,
                stale: false,
                sortIndex: 1
            ),
            TrayItemPresentation(
                id: UUID(),
                displayName: "project",
                isDirectory: true,
                stale: false,
                sortIndex: 2
            ),
            TrayItemPresentation(
                id: UUID(),
                displayName: "deleted-file.txt",
                isDirectory: false,
                stale: true,
                sortIndex: 3
            ),
        ]
    }
}

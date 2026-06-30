import AppKit
import SwiftUI

/// 左レール用パネルの生成・配置・画面外補正を担う（アーキテクチャ v0.1 §3.2）。
/// 画面左端に固定表示し、トレイ作成・収納タブ一覧・最小メニューを担う。
@MainActor
final class SideRailController {
    private let layoutEngine: LayoutEngine
    private(set) var panel: SideRailPanel?

    /// 表示内容を供給するプロバイダ。Application 層で差し替える。
    var contentProvider: (() -> AnyView)?

    init(layoutEngine: LayoutEngine = LayoutEngine()) {
        self.layoutEngine = layoutEngine
    }

    /// 左レールを表示する。画面左端の全スクリーンをまたぐ高さで固定。
    func show() {
        let visible = LayoutEngine.combinedVisibleFrame()
        let width = layoutEngine.sideRailWidth
        let frame = CGRect(
            x: visible.minX,
            y: visible.minY,
            width: width,
            height: visible.height
        )

        if panel == nil {
            let panel = SideRailPanel(
                contentRect: frame,
                styleMask: [.nonactivatingPanel, .borderless],
                backing: .buffered,
                defer: false
            )
            panel.level = .floating
            panel.collectionBehavior = [
                .canJoinAllSpaces,
                .stationary,
                .ignoresCycle,
                .fullScreenAuxiliary
            ]
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            self.panel = panel
        }

        let content = contentProvider?() ?? AnyView(EmptyView())
        if let hosting = panel?.contentView as? NSHostingView<AnyView> {
            hosting.rootView = content
        } else {
            panel?.contentView = NSHostingView(rootView: content)
        }

        panel?.setFrame(frame, display: true)
        panel?.orderFrontRegardless()
    }

    /// コンテンツを差し替える（収納タブ増減時など）。
    func refresh() {
        let content = contentProvider?() ?? AnyView(EmptyView())
        if let hosting = panel?.contentView as? NSHostingView<AnyView> {
            hosting.rootView = content
        } else {
            panel?.contentView = NSHostingView(rootView: content)
        }
    }

    /// 画面構成変更時に frame を再計算する。
    func repositionIfNeeded() {
        guard let panel, panel.isVisible else { return }
        let visible = LayoutEngine.combinedVisibleFrame()
        let width = layoutEngine.sideRailWidth
        let frame = CGRect(
            x: visible.minX,
            y: visible.minY,
            width: width,
            height: visible.height
        )
        if panel.frame != frame {
            panel.setFrame(frame, display: true, animate: false)
        }
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
    }
}

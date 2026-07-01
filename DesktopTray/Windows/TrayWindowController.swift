import AppKit
import SwiftUI

/// SwiftUI コンテンツ上での mouseDown が AppKit 標準のウィンドウ背景ドラッグを
/// 一切トリガーしないようにする `NSHostingView`（Fix: アイテムD&D）。
/// `mouseDownCanMoveWindow` は AppKit がウィンドウ移動の可否を実際に判定する箇所であり、
/// `NSWindow.isMovableByWindowBackground` を動的に切り替えるだけでは確実に反映されなかった
/// （詳細は `TrayPanel` のコメント参照）。ここで常に `false` を返すことで、
/// アイテムの `.draggable` がウィンドウ移動と競合する余地を完全になくす。
/// トレイ自体の移動は `TrayPanel.sendEvent` 側で自前実装している。
final class NonMovableHostingView<Content: View>: NSHostingView<Content> {
    override var mouseDownCanMoveWindow: Bool { false }
}

/// 1 トレイ = 1 `NSPanel` の生成・更新・破棄を担う（アーキテクチャ v0.1 §3.2）。
/// ドラッグ追従・左端 snap 判定・収納/展開アニメーションをここで制御する。
///
/// 透明化（Fix A）: `NSVisualEffectView` を `panel.contentView` に昇格し、
/// `NSHostingView` をそのサブビューに乗せる。`.behindWindow` ブレンドが効くようになり
/// デスクトップ背景がトレイを透けて見える。
/// ウィンドウレベル（Fix B）: `.normal` で通常ウィンドウと同列にし、ブラウザにフォーカスを
/// 当てればトレイは背後に回る。
@MainActor
final class TrayWindowController {
    let trayID: UUID
    private let layoutEngine: LayoutEngine
    /// アイテム上での mouseDown 時にウィンドウ背景ドラッグを無効化するための共有トラッカー（Fix: アイテムD&D）。
    private let itemFrameTracker = ItemFrameTracker()

    private(set) var panel: TrayPanel?
    private var moveObserver: NSObjectProtocol?

    /// ドラッグ中にフレームが変化したとき呼ばれる。
    var onFrameChanged: (CGRect) -> Void = { _ in }
    /// 左端 snap 領域に入った/抜けたとき呼ばれる。
    var onSnapStateChanged: (Bool) -> Void = { _ in }
    /// パネルが閉じられたとき呼ばれる。
    var onClose: (() -> Void)?
    /// 同一トレイ内で並び替えが確定したとき呼ばれる（itemID, newIndex）。
    var onItemReorder: (UUID, Int) -> Void = { _, _ in }
    /// 別トレイからアイテムが移動してきたとき呼ばれる（itemID, sourceTrayID）。
    var onItemMove: (UUID, UUID) -> Void = { _, _ in }

    init(trayID: UUID, layoutEngine: LayoutEngine) {
        self.trayID = trayID
        self.layoutEngine = layoutEngine
    }

    /// SwiftUI コンテンツを指定 frame で表示する。
    func show<Content: View>(
        @ViewBuilder content: () -> Content,
        frame: CGRect
    ) {
        if panel == nil {
            let panel = TrayPanel(
                contentRect: frame,
                styleMask: [.nonactivatingPanel, .borderless, .resizable],
                backing: .buffered,
                defer: false
            )
            // Fix B: .floating だと常に最前面でブラウザ等を隠すため .normal へ。
            panel.level = .normal
            panel.collectionBehavior = [
                .canJoinAllSpaces,
                .stationary,
                .ignoresCycle,
                .fullScreenAuxiliary
            ]
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.animationBehavior = .none
            panel.itemFrameTracker = itemFrameTracker
            self.panel = panel

            moveObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didMoveNotification,
                object: panel,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.handleMoved()
                }
            }
        }

        let rootView = AnyView(content().environment(\.itemFrameTracker, itemFrameTracker))
        installGlassContentView(rootView: rootView, size: frame.size)

        panel?.setFrame(frame, display: true)
        panel?.orderFrontRegardless()
    }

    /// 透明度を独立して調整できるよう、ガラス背景 (`NSVisualEffectView`) と
    /// SwiftUI コンテンツ (`NSHostingView`) を親子ではなく兄弟ビューとして
    /// コンテナ (`panel.contentView`) に乗せる。`effectView.alphaValue` を下げても
    /// アイコン/文字の視認性に影響しない（Fix: 透明度調整）。
    /// 既存の場合は hostingView の rootView を差し替えるだけ。
    private func installGlassContentView(rootView: AnyView, size: CGSize) {
        guard let panel else { return }

        if let container = panel.contentView,
           let hostingView = container.subviews.compactMap({ $0 as? NonMovableHostingView<AnyView> }).first {
            hostingView.rootView = rootView
            return
        }

        let container = NSView(frame: NSRect(origin: .zero, size: size))
        container.wantsLayer = true
        container.layer?.cornerRadius = TrayTheme.cornerRadius
        container.layer?.masksToBounds = true

        let effectView = NSVisualEffectView(frame: container.bounds)
        effectView.material = .sidebar
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.autoresizingMask = [.width, .height]
        effectView.wantsLayer = true
        effectView.alphaValue = TrayTheme.glassAlpha
        container.addSubview(effectView)

        let hostingView = NonMovableHostingView(rootView: rootView)
        hostingView.frame = container.bounds
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        container.addSubview(hostingView)

        // 別ウィンドウ（別トレイ）から発生したドラッグを確実に受け取るためのネイティブ受け口。
        // SwiftUI のクロスウィンドウ D&D は信頼できないため使わない（不具合修正: トレイ間移動）。
        let dropView = TrayItemDropView(frame: container.bounds)
        dropView.autoresizingMask = [.width, .height]
        dropView.trayID = trayID
        dropView.itemFrameTracker = itemFrameTracker
        dropView.onReorder = { [weak self] itemID, index in
            self?.onItemReorder(itemID, index)
        }
        dropView.onMove = { [weak self] itemID, sourceTrayID in
            self?.onItemMove(itemID, sourceTrayID)
        }
        container.addSubview(dropView)

        let gripSize: CGFloat = 16
        let grip = ResizeGripView(
            frame: NSRect(x: size.width - gripSize, y: 0, width: gripSize, height: gripSize)
        )
        grip.autoresizingMask = [.minXMargin, .maxYMargin]
        grip.minSize = NSSize(
            width: TrayTheme.trayWidthRange.lowerBound,
            height: layoutEngine.minTrayHeight
        )
        grip.onResizeEnd = { [weak self] in
            guard let self, let panel = self.panel else { return }
            self.onFrameChanged(panel.frame)
        }
        container.addSubview(grip)
        panel.resizeGripView = grip

        panel.contentView = container
    }

    /// コンテンツ（AnyView）を差し替える。ガラス背景は維持したまま SwiftUI のみ更新。
    func updateContentView(_ rootView: AnyView) {
        guard let panel,
              let hostingView = panel.contentView?.subviews.compactMap({ $0 as? NonMovableHostingView<AnyView> }).first
        else { return }
        hostingView.rootView = AnyView(rootView.environment(\.itemFrameTracker, itemFrameTracker))
    }

    /// パネルを非表示にする。破棄はしない。
    func hide() {
        panel?.orderOut(nil)
    }

    /// パネルを再表示する。
    func unhide() {
        panel?.orderFrontRegardless()
    }

    /// frame を更新（アニメーション付き/なし）。
    func updateFrame(_ frame: CGRect, animate: Bool) {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = animate ? 0.3 : 0.0
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.setFrame(frame, display: true, animate: animate)
        }
    }

    /// 収納: 左端画面外へスライドし、tabWidth だけ覗かせる（Fix D）。
    /// `orderOut` しないため、パネル自体がタブになりクリックで展開できる。
    func collapseToEdge(savedFrame: CGRect, tabWidth: CGFloat) {
        guard let panel else { return }
        let collapsed = layoutEngine.collapsedEdgeFrame(saved: savedFrame, tabWidth: tabWidth)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.32
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.setFrame(collapsed, display: true, animate: true)
        }
    }

    /// 展開: 保存 frame へスライドで戻す（Fix D）。
    func expandFromEdge(savedFrame: CGRect) {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.36
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.setFrame(savedFrame, display: true, animate: true)
        }
    }

    /// パネルを破棄する。
    func close() {
        if let moveObserver, let panel {
            NotificationCenter.default.removeObserver(
                moveObserver,
                name: NSWindow.didMoveNotification,
                object: panel
            )
        }
        moveObserver = nil
        panel?.orderOut(nil)
        panel = nil
    }

    /// 現在の可視 frame。非表示時は nil。
    var currentFrame: CGRect? { panel?.isVisible == true ? panel?.frame : nil }

    private func handleMoved() {
        guard let panel else { return }
        let frame = panel.frame
        let snapped = layoutEngine.shouldSnap(frame: frame)
        onFrameChanged(frame)
        onSnapStateChanged(snapped)
    }
}

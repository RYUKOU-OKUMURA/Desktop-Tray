import AppKit
import SwiftUI

/// 左端固定の TabRail ウィンドウを管理する（Fix G）。
@MainActor
final class TabRailController {
    private let layoutEngine: LayoutEngine
    private var panel: TabRailPanel?

    init(layoutEngine: LayoutEngine = LayoutEngine()) {
        self.layoutEngine = layoutEngine
    }

    func refresh(
        collapsedTrays: [Tray],
        itemCounts: [UUID: Int],
        screen: CGRect? = nil,
        onExpand: @escaping (UUID) -> Void,
        onNewTray: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        let visible = screen ?? LayoutEngine.primaryScreenVisibleFrame()
        let tabs = collapsedTrays
            .sorted { $0.tabIndex < $1.tabIndex }
            .map { tray in
                TabRailEntry(
                    id: tray.id,
                    name: tray.name,
                    color: tray.color,
                    itemCount: itemCounts[tray.id] ?? 0,
                    isSmart: tray.isSmart
                )
            }

        let frame = layoutEngine.tabRailWindowFrame(tabCount: tabs.count, screen: visible)
        let rootView = AnyView(
            TabRailView(
                tabs: tabs,
                onExpand: onExpand,
                onNewTray: onNewTray,
                onOpenSettings: onOpenSettings
            )
        )

        if panel == nil {
            let panel = TabRailPanel(
                contentRect: frame,
                styleMask: [.nonactivatingPanel, .borderless],
                backing: .buffered,
                defer: false
            )
            panel.level = .normal
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

        installGlassContentView(rootView: rootView, size: frame.size)
        panel?.setFrame(frame, display: true)
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func show() {
        panel?.orderFrontRegardless()
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
    }

    /// ガラス背景と SwiftUI コンテンツを兄弟ビューに分離し、
    /// `effectView.alphaValue` だけで透明度を調整できるようにする（Fix: 透明度調整）。
    private func installGlassContentView(rootView: AnyView, size: CGSize) {
        guard let panel else { return }

        if let container = panel.contentView,
           let hostingView = container.subviews.compactMap({ $0 as? NSHostingView<AnyView> }).first {
            hostingView.rootView = rootView
            return
        }

        let container = NSView(frame: NSRect(origin: .zero, size: size))
        container.wantsLayer = true

        let effectView = NSVisualEffectView(frame: container.bounds)
        effectView.material = .sidebar
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.autoresizingMask = [.width, .height]
        effectView.wantsLayer = true
        effectView.alphaValue = TrayTheme.glassAlpha
        container.addSubview(effectView)

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = container.bounds
        hostingView.autoresizingMask = [.width, .height]
        container.addSubview(hostingView)

        panel.contentView = container
    }
}

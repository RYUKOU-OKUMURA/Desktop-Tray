import AppKit

/// トレイ表示用のカスタム `NSPanel`。
/// `.nonactivatingPanel` + `.borderless` でデスクトップ上にフローティングする半透明パネルを実現する
/// （技術スタック v0.1 §6.2）。
final class TrayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    /// `nonactivatingPanel` でもドラッグ可能にするため、背景ドラッグを許可。
    override var isMovableByWindowBackground: Bool {
        get { true }
        set { /* 固定 */ }
    }

    /// `nonactivatingPanel` はクリックしても他アプリのウィンドウより手前に上がらない仕様のため、
    /// クリック時に明示的にこのパネルだけを最前面へ引き上げる。
    /// `orderFrontRegardless()` はアプリのアクティブ化（他アプリからのフォーカス奪取）を伴わないため、
    /// nonactivating の「他アプリの作業を妨げない」特性は維持したまま前面化だけを行える。
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown || event.type == .rightMouseDown {
            orderFrontRegardless()
        }
        super.sendEvent(event)
    }
}

/// 左端 TabRail 用の固定パネル（Fix G）。
final class TabRailPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override var isMovableByWindowBackground: Bool {
        get { false }
        set { /* 固定 */ }
    }

    /// トレイパネルと同様、クリックで最前面に引き上げる（Fix: nonactivating パネルの前面化）。
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown || event.type == .rightMouseDown {
            orderFrontRegardless()
        }
        super.sendEvent(event)
    }
}

/// トレイパネル右下角のリサイズグリップ。
/// `.borderless` パネルの OS 標準リサイズ判定領域は数px しかなく掴みづらいため、
/// 明示的にクリック可能なハンドルでドラッグリサイズを提供する。
final class ResizeGripView: NSView {
    /// リサイズ確定（マウスアップ）時に呼ばれる。
    var onResizeEnd: (() -> Void)?
    /// 最小サイズ（幅・高さ）。
    var minSize: NSSize = NSSize(width: 200, height: 160)

    private var initialMouseLocation: NSPoint?
    private var initialWindowFrame: NSRect?
    private var trackingArea: NSTrackingArea?
    private let imageView: NSImageView

    override init(frame frameRect: NSRect) {
        imageView = NSImageView(frame: NSRect(origin: .zero, size: frameRect.size))
        super.init(frame: frameRect)
        wantsLayer = true

        if let image = NSImage(
            systemSymbolName: "arrow.up.left.and.arrow.down.right",
            accessibilityDescription: NSLocalizedString("tray.resize", comment: "")
        ) {
            imageView.image = image
            imageView.contentTintColor = .secondaryLabelColor
            imageView.alphaValue = 0.55
        }
        imageView.autoresizingMask = [.width, .height]
        imageView.imageScaling = .scaleProportionallyDown
        addSubview(imageView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseEntered(with event: NSEvent) {
        imageView.animator().alphaValue = 1.0
    }

    override func mouseExited(with event: NSEvent) {
        imageView.animator().alphaValue = 0.55
    }

    override func mouseDown(with event: NSEvent) {
        initialMouseLocation = NSEvent.mouseLocation
        initialWindowFrame = window?.frame
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window,
              let initialMouseLocation,
              let initialWindowFrame
        else { return }

        let current = NSEvent.mouseLocation
        let dx = current.x - initialMouseLocation.x
        let dy = current.y - initialMouseLocation.y

        let newWidth = max(initialWindowFrame.width + dx, minSize.width)
        let newHeight = max(initialWindowFrame.height - dy, minSize.height)
        let newOriginY = initialWindowFrame.minY + (initialWindowFrame.height - newHeight)

        let newFrame = NSRect(
            x: initialWindowFrame.minX,
            y: newOriginY,
            width: newWidth,
            height: newHeight
        )
        window.setFrame(newFrame, display: true)
    }

    override func mouseUp(with event: NSEvent) {
        initialMouseLocation = nil
        initialWindowFrame = nil
        onResizeEnd?()
    }
}

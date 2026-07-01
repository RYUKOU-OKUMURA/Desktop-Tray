import AppKit

/// 各アイテム（ファイル/フォルダ）の現在の表示矩形を SwiftUI 側から AppKit 側へ伝える。
/// `TrayPanel` は mouseDown の座標をこの矩形群と突き合わせて、アイテム上での mouseDown なら
/// 自前の背景ドラッグ（＝ウィンドウ移動）を開始しない。
/// 参照型で `TrayWindowController` が生成し、SwiftUI 側には `.environment` 経由で配る。
/// 矩形はパネルコンテンツ左上原点（SwiftUI 座標系）で保持する。
@MainActor
final class ItemFrameTracker {
    var itemFrames: [CGRect] = []

    func contains(_ point: CGPoint) -> Bool {
        itemFrames.contains { $0.contains(point) }
    }
}

/// トレイ表示用のカスタム `NSPanel`。
/// `.nonactivatingPanel` + `.borderless` でデスクトップ上にフローティングする半透明パネルを実現する
/// （技術スタック v0.1 §6.2）。
///
/// 背景ドラッグ（トレイ移動）は AppKit 標準の `isMovableByWindowBackground` を使わず、
/// このクラスで完全に自前実装している。
/// 経緯（Fix: アイテムD&D）: `isMovableByWindowBackground` を動的に true/false 切り替える実装を
/// 2度試したが（ホバー判定・mouseDown 座標判定）どちらも改善しなかった。調査の結果、
/// ウィンドウ移動の可否は `isMovableByWindowBackground` そのものではなく、実際に mouseDown を
/// 受け取った `NSView` の `mouseDownCanMoveWindow` が個別に判定しており、かつ SwiftUI の
/// ジェスチャ処理とウィンドウ移動処理は「どちらか一方が勝つ」のではなく同時に走り得ることが
/// わかった。そのため `NSHostingView` 側は `NonMovableHostingView`
/// （`TrayWindowController` 参照）で `mouseDownCanMoveWindow` を常に `false` にして
/// AppKit 標準の自動移動を完全に無効化し、トレイ移動自体は本クラスの `sendEvent` で
/// mouseDown/mouseDragged/mouseUp を自前追跡して `setFrameOrigin` で実現する。
/// こうすることで「アイテム上かどうか」の判定ロジックを完全に自分たちのコードだけで完結させ、
/// AppKit 内部のブラックボックスな判定タイミングに依存しないようにしている。
final class TrayPanel: NSPanel {
    /// アイテム矩形の共有元（`TrayWindowController` が設定する）。
    var itemFrameTracker: ItemFrameTracker?
    /// リサイズグリップ（`TrayWindowController` が設定する）。この上の mouseDown は
    /// 背景ドラッグの対象から除外し、グリップ自身のリサイズ処理に譲る。
    weak var resizeGripView: NSView?

    /// 背景ドラッグの進行状態（開始時のマウス位置とウィンドウ原点）。
    private var backgroundDrag: (mouseLocation: NSPoint, windowOrigin: NSPoint)?
    /// この距離（pt）を超えて動くまではウィンドウを動かさない（クリックの手ぶれ対策）。
    private static let backgroundDragThreshold: CGFloat = 3

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    /// AppKit 標準の自動移動は使わない（上記クラスコメント参照）。常に無効化しておくことで、
    /// 万一 `NonMovableHostingView` 以外の subview が将来追加されても暴走しない。
    override var isMovableByWindowBackground: Bool {
        get { false }
        set { /* 固定 */ }
    }

    /// `nonactivatingPanel` はクリックしても他アプリのウィンドウより手前に上がらない仕様のため、
    /// クリック時に明示的にこのパネルだけを最前面へ引き上げる。
    /// `orderFrontRegardless()` はアプリのアクティブ化（他アプリからのフォーカス奪取）を伴わないため、
    /// nonactivating の「他アプリの作業を妨げない」特性は維持したまま前面化だけを行える。
    ///
    /// あわせて、アイテムでもリサイズグリップでもない場所での mouseDown を起点に、
    /// 自前のウィンドウ背景ドラッグ（トレイ移動）を実装する。
    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            orderFrontRegardless()
            if isDraggableBackgroundPoint(event.locationInWindow) {
                backgroundDrag = (NSEvent.mouseLocation, frame.origin)
            } else {
                backgroundDrag = nil
            }
        case .leftMouseDragged:
            if let backgroundDrag {
                let current = NSEvent.mouseLocation
                let dx = current.x - backgroundDrag.mouseLocation.x
                let dy = current.y - backgroundDrag.mouseLocation.y
                // ヘッダー上のボタン等をタップした際の微小な手ぶれで意図せずウィンドウが
                // ずれてタップ判定を壊さないよう、一定距離動くまでは実際には動かさない。
                if max(abs(dx), abs(dy)) >= Self.backgroundDragThreshold {
                    setFrameOrigin(
                        NSPoint(x: backgroundDrag.windowOrigin.x + dx, y: backgroundDrag.windowOrigin.y + dy)
                    )
                }
            }
        case .leftMouseUp:
            backgroundDrag = nil
        case .rightMouseDown:
            orderFrontRegardless()
        default:
            break
        }
        super.sendEvent(event)
    }

    /// window 座標（左下原点）の点が「アイテムでもリサイズグリップでもない背景」かどうかを判定する。
    private func isDraggableBackgroundPoint(_ locationInWindow: NSPoint) -> Bool {
        if let resizeGripView, resizeGripView.frame.contains(locationInWindow) {
            return false
        }
        guard let tracker = itemFrameTracker, let contentHeight = contentView?.bounds.height else {
            return true
        }
        // window 座標（左下原点）→ SwiftUI 座標（左上原点）へ変換。
        let flipped = CGPoint(x: locationInWindow.x, y: contentHeight - locationInWindow.y)
        return !tracker.contains(flipped)
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
